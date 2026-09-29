include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//keda"
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs = {
    name = "test-gke"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name = dependency.gke.outputs.name
  keda_version = "2.15.1"
}
