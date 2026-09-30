include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//prometheus-stack"
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs = {
    name = "test-gke"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# istio-system namespace'ine ServiceMonitor/PodMonitor yazıyor
dependencies {
  paths = ["../istio"]
}

inputs = {
  cluster_name                  = dependency.gke.outputs.name
  kube_prometheus_stack_version = "65.1.0"

  # Bot token: kubectl -n monitoring create secret generic grafana-telegram --from-literal=TELEGRAM_BOT_TOKEN=...
  telegram_chat_id = "7067419664"
}
