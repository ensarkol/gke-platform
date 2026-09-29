include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//agent"
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs = {
    name = "test-gke"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "prometheus_stack" {
  config_path = "../prometheus-stack"

  mock_outputs = {
    grafana_admin_password = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name           = dependency.gke.outputs.name
  artifact_registry_repo = local.common.artifact_registry_repo
  image_tag              = get_env("IMAGE_TAG", "latest")
  grafana_admin_password = dependency.prometheus_stack.outputs.grafana_admin_password

  # Apply sırasında: kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
  grafana_url  = "http://localhost:3000"
  gemini_model = "gemini-2.0-flash"
}
