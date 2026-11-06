# Environment variables the Paperless app already had before OpenTofu managed
# its login, copied from `midclt call app.config paperless-ngx`
# (.paperless.additional_envs, container paperless). The login's two
# variables are added in main.tf; secrets never go here (public repository).
archive_environment = []
