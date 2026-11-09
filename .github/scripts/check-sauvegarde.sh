#!/usr/bin/env bash
# Run services/sauvegarde's script, rendered from the inventory, against a
# small ZFS pool laid out like Bruxelles' (CHECK_ZFS_POOL, empty), with
# restic's repository on a local folder instead of Google Drive, and check
# that:
# - the selected datasets are backed up with their children, an encrypted
#   one and one matched by a pattern included,
# - excluded datasets, their children and unselected datasets are not,
# - the next run only adds what changed,
# - no snapshot or mount is left behind, and the result is written for
#   node_exporter, with the repository's size and snapshot count,
# - a dataset whose key is not loaded fails the run, which still cleans up
#   and reports the failure,
# - a run that finds another one running leaves it alone.
# Bruxelles' own settings must render a valid script too.
set -euo pipefail

pool=${CHECK_ZFS_POOL:?CHECK_ZFS_POOL names an empty ZFS pool}
directory=$(mktemp -d)
service=$directory/Sauvegarde
textfile=$directory/textfile
key=$directory/key

compose() {
    (cd "$service" && sudo docker compose "$@")
}
restic() {
    compose run --rm --no-TTY --quiet-pull restic "$@"
}
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        sudo sh -c "tail -n 40 '$service'/logs/*.log" 2> /dev/null || true
        compose logs --no-color --tail 40 || true
    fi
    compose down --volumes --timeout 5 > /dev/null 2>&1 || true
    sudo umount -R /run/sauvegarde 2> /dev/null || true
    sudo rm -rf "$directory"
    exit "$status"
}
trap cleanup EXIT

render() {
    # $1: destination, then extra variables
    local destination=$1
    shift
    if ! output=$(uv run ansible bruxelles -c local -e "ansible_python_interpreter=$(uv run which python)" \
        -e sauvegarde_path=/srv/Sauvegarde -e sauvegarde_textfile_directory=/srv/textfile "$@" \
        -m ansible.builtin.template -a "src=services/sauvegarde/sauvegarde.sh.j2 dest=$destination"); then
        echo "$output"
        exit 1
    fi
}

# Bruxelles' datasets, as the inventory lists them
render "$directory/bruxelles.sh"
bash -n "$directory/bruxelles.sh"
grep -q "^roots=(Donnees/Applications Donnees/Applications_chiffrees " "$directory/bruxelles.sh"
grep -q "^excluded=(Donnees/ix-apps/app_mounts/gitea)" "$directory/bruxelles.sh"
echo "ok    Bruxelles' settings render a valid script"

# A pool like Bruxelles': selected, excluded and unselected datasets
printf '%s' check-sauvegarde-passphrase > "$key"
create() {
    sudo zfs create "$@"
}
create "$pool/Applications"
create "$pool/Applications/Nuage"
create "$pool/Applications/Nuage/User_data"
create -o encryption=on -o keyformat=passphrase -o "keylocation=file://$key" "$pool/Applications_chiffrees"
create "$pool/Applications_chiffrees/Vaultwarden"
create "$pool/Mediatheque"
create -p "$pool/ix-apps/app_mounts/gitea/data"
create "$pool/ix-apps/app_mounts/kept"
create "$pool/ix-apps/docker"
create -p "$pool/.system/configs-0123"
write() {
    # $1: dataset, $2: file, $3: content
    printf '%s' "$3" | sudo tee "$(zfs get -H -o value mountpoint "$pool/$1")/$2" > /dev/null
}
write Applications app.txt applications
write Applications/Nuage/User_data photo.txt photo
write Applications_chiffrees secret.txt secret
write Applications_chiffrees/Vaultwarden db.txt vaultwarden
write Mediatheque film.txt film
write ix-apps/app_mounts/gitea/data repo.txt gitea
write ix-apps/app_mounts/kept config.txt kept
write ix-apps/docker image.txt image
write .system/configs-0123 config.db truenas

# The service folder, as deploy.yml lays it out, with restic's repository in
# a local folder served by the same rclone
mkdir -p "$service/cache" "$service/logs" "$service/repository"
chmod 0777 "$service/repository"
# restic runs as root without DAC_OVERRIDE: its cache must be root's, as
# the role creates it on Bruxelles
sudo chown root:root "$service/cache"
cp services/sauvegarde/compose.yml "$service/"
cat > "$service/.env" <<EOF
REMOTE_PATH=unused
BANDWIDTH_LIMIT=off
DRIVE_CLIENT_ID=unused
DRIVE_CLIENT_SECRET=unused
DRIVE_TOKEN={}
RESTIC_PASSWORD=check-sauvegarde
EOF
cat > "$service/compose.override.yml" <<'EOF'
services:
  rclone:
    command: [serve, restic, /repository, --addr=:8080]
    volumes:
      - ./repository:/repository
EOF
render "$service/sauvegarde.sh" \
    -e "{\"sauvegarde_pool\": \"$pool\", \"sauvegarde_path\": \"$service\", \"sauvegarde_textfile_directory\": \"$textfile\",
         \"sauvegarde_datasets\": [\"$pool/Applications\", \"$pool/Applications_chiffrees\", \"$pool/ix-apps/app_mounts\",
                                   \"$pool/.system/configs-*\"],
         \"sauvegarde_excluded_datasets\": [\"$pool/ix-apps/app_mounts/gitea\"]}"
compose up -d --wait --quiet-pull
restic init > /dev/null

run() {
    sudo bash "$service/sauvegarde.sh"
}
metric() {
    sudo sed -n "s/^$1 //p" "$textfile/sauvegarde.prom"
}
leftovers() {
    # Fails when a snapshot or a mount of the script is left
    if sudo zfs list -H -o name -t snapshot -r "$pool" | grep -q '@sauvegarde$'; then
        echo "a snapshot is left: $(sudo zfs list -H -o name -t snapshot -r "$pool")"
        return 1
    fi
    if mountpoint -q /run/sauvegarde; then
        echo "/run/sauvegarde is still mounted"
        return 1
    fi
}

run
listed=$(restic ls latest)
for path in /source/Applications/app.txt /source/Applications/Nuage/User_data/photo.txt \
    /source/Applications_chiffrees/secret.txt /source/Applications_chiffrees/Vaultwarden/db.txt \
    /source/ix-apps/app_mounts/kept/config.txt /source/.system/configs-0123/config.db; do
    if ! grep -qxF "$path" <<< "$listed"; then
        echo "$path is not backed up; the snapshot holds:"
        echo "$listed"
        exit 1
    fi
done
for path in Mediatheque gitea docker; do
    if grep -q "/$path" <<< "$listed"; then
        echo "$path is backed up: $(grep "/$path" <<< "$listed")"
        exit 1
    fi
done
if [ "$(restic dump latest /source/Applications_chiffrees/Vaultwarden/db.txt)" != vaultwarden ]; then
    echo "the encrypted dataset's file does not read back"
    exit 1
fi
leftovers
if [ "$(metric sauvegarde_last_run_success)" != 1 ] || [ "$(metric sauvegarde_last_success_timestamp_seconds)" -le 0 ] \
    || [ "$(metric sauvegarde_last_run_added_bytes)" -le 0 ]; then
    echo "the first run reports: $(sudo cat "$textfile/sauvegarde.prom")"
    exit 1
fi
echo "ok    the selected datasets and their children are backed up, the others are not"
# The repository's size and snapshot count, read on the first run
repository_size=$(sudo sed -n 's/^sauvegarde_repository_size_bytes //p' "$textfile/sauvegarde_repository.prom" 2> /dev/null)
repository_snapshots=$(sudo sed -n 's/^sauvegarde_repository_snapshots //p' "$textfile/sauvegarde_repository.prom" 2> /dev/null)
if [ "${repository_size:-0}" -le 0 ] || [ "$repository_snapshots" != 1 ]; then
    echo "the first run reports the repository as: $(sudo cat "$textfile/sauvegarde_repository.prom" 2> /dev/null)"
    exit 1
fi
echo "ok    the first run reports the repository's size and snapshot count"

first_success=$(metric sauvegarde_last_success_timestamp_seconds)
sleep 1
write Applications_chiffrees/Vaultwarden db.txt vaultwarden-changed
run
if [ "$(restic snapshots --json | jq length)" != 2 ] \
    || [ "$(restic dump latest /source/Applications_chiffrees/Vaultwarden/db.txt)" != vaultwarden-changed ]; then
    echo "the second run did not record the change"
    exit 1
fi
added=$(metric sauvegarde_last_run_added_bytes)
if [ "$added" -le 0 ] || [ "$added" -ge 100000 ]; then
    echo "the second run added $added bytes, not just the change"
    exit 1
fi
leftovers
echo "ok    the next run adds only what changed"

# A locked dataset: the run fails, cleans up and says so
second_success=$(metric sauvegarde_last_success_timestamp_seconds)
if [ "$second_success" -le "$first_success" ]; then
    echo "the second success was not recorded"
    exit 1
fi
sudo zfs unmount "$pool/Applications_chiffrees"
sudo zfs unload-key "$pool/Applications_chiffrees"
if run; then
    echo "a run with a locked dataset succeeded"
    exit 1
fi
leftovers
if [ "$(metric sauvegarde_last_run_success)" != 0 ] \
    || [ "$(metric sauvegarde_last_success_timestamp_seconds)" != "$second_success" ]; then
    echo "the failed run reports: $(sudo cat "$textfile/sauvegarde.prom")"
    exit 1
fi
if [ "$(restic snapshots --json | jq length)" != 2 ]; then
    echo "the failed run left a snapshot in the repository"
    exit 1
fi
echo "ok    a locked dataset fails the run, which cleans up and reports it"
sudo zfs load-key "$pool/Applications_chiffrees"
sudo zfs mount "$pool/Applications_chiffrees"

# Another run still going (the first upload takes days)
sudo flock "$service/.lock" sleep 20 &
holder=$!
sleep 1
run
wait "$holder"
if ! sudo grep -qh "A backup is still running" "$service"/logs/*.log; then
    echo "a run did not notice the one still going"
    exit 1
fi
if [ "$(metric sauvegarde_last_run_success)" != 0 ]; then
    echo "a run that left the running one alone wrote a result"
    exit 1
fi
echo "ok    a run leaves a running one alone"
