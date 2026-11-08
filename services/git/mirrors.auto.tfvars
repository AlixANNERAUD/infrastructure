# GitHub owners whose repositories (forks excepted) are mirrored, and the Gitea
# user or organization that holds their mirrors. Each needs a token in
# github_tokens (vault/git/vault.yml).
owners = {
  AlixANNERAUD = {
    type        = "user"
    gitea_owner = "alix_anneraud"
  }
  xila-project = {
    type        = "org"
    gitea_owner = "Xila"
  }
}

# Mirrors made under a repository's former GitHub name: adopted under that name
aliases = {
  "AlixANNERAUD/portfolio"        = "Web_site"
  "AlixANNERAUD/deez_nalyzer"     = "Machine_Learning_demonstrator"
  "AlixANNERAUD/mini_train_store" = "MiniTrainStore"
}

# Gitea repositories that have a mirror's name but are not its mirror: never
# adopted, and the plan fails until they are deleted or renamed in Gitea
excluded_imports = {
  # alix_anneraud/Odor_localization mirrors Delivery_route_optimization
  "AlixANNERAUD/odor_localization" = 14
}
