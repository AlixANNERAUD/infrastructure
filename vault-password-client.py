#!/usr/bin/env python3
"""Print the Ansible Vault password, kept in the system keyring.

Ansible runs this file because ANSIBLE_VAULT_PASSWORD_FILE points to it (set in
mise.toml) and reads the password from its output. The first time on a machine,
it asks for the password, checks it against a vault file and stores it in the
keyring (macOS Keychain, Windows Credential Locker, Secret Service on Linux).

    vault-password-client.py            print the password, asking for it if needed
    vault-password-client.py --forget   remove it from the keyring
"""

import argparse
import getpass
import os
import sys
from pathlib import Path

import keyring
from keyring.errors import KeyringError, PasswordDeleteError

SERVICE = "infrastructure"
USERNAME = "ansible-vault"
# Encrypted file the typed password is checked against before it is stored
CHECK_FILE = Path(__file__).resolve().parent / "vault" / "ansible" / "vault.yml"


def say(message: str) -> None:
    """Tell the user, on the terminal: Ansible captures this script's error output."""
    try:
        with open("/dev/tty", "w") as terminal:
            print(message, file=terminal)
    except OSError:
        print(message, file=sys.stderr)


def is_correct(password: str) -> bool:
    """Whether the password decrypts CHECK_FILE (true when there is nothing to check)."""
    if not CHECK_FILE.is_file():
        return True
    from ansible.constants import DEFAULT_VAULT_ID_MATCH
    from ansible.errors import AnsibleError
    from ansible.parsing.vault import VaultLib, VaultSecret

    vault = VaultLib([(DEFAULT_VAULT_ID_MATCH, VaultSecret(password.encode()))])
    try:
        vault.decrypt(CHECK_FILE.read_bytes())
    except AnsibleError:
        return False
    return True


def ask() -> str:
    """Ask on the terminal until the password decrypts the vault."""
    try:
        open("/dev/tty").close()
    except OSError:
        sys.exit("No vault password stored and no terminal to ask for it: set ANSIBLE_VAULT_PASSWORD.")
    for _ in range(3):
        password = getpass.getpass("Ansible Vault password: ")
        if is_correct(password):
            return password
        say(f"That password doesn't decrypt {CHECK_FILE.relative_to(CHECK_FILE.parents[2])}.")
    sys.exit("No valid vault password given.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--forget", action="store_true", help="remove the password from the keyring")
    # Ansible passes the vault ID to scripts named *-client; there is only one vault password here
    parser.add_argument("--vault-id", help=argparse.SUPPRESS)
    arguments = parser.parse_args()

    if arguments.forget:
        try:
            keyring.delete_password(SERVICE, USERNAME)
        except PasswordDeleteError:
            say("No vault password in the keyring.")
        else:
            say("Vault password removed from the keyring.")
        return

    # Machines without a keyring (CI) can pass it in the environment
    password = os.environ.get("ANSIBLE_VAULT_PASSWORD")
    if not password:
        try:
            password = keyring.get_password(SERVICE, USERNAME)
        except KeyringError as error:
            say(f"Keyring unavailable ({error}); the password won't be remembered.")
            password = ask()
        else:
            if password is None:
                password = ask()
                keyring.set_password(SERVICE, USERNAME, password)
                say("Vault password stored in the keyring.")
    print(password)


if __name__ == "__main__":
    main()
