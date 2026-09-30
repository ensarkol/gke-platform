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

dependencies {
  paths = ["../istio"]
}

inputs = {
  cluster_name                  = dependency.gke.outputs.name
  kube_prometheus_stack_version = "65.1.0"

  telegram_enabled = true
}
