include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//elk"
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs = {
    name = "test-gke"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  cluster_name         = dependency.gke.outputs.name
  eck_operator_version = "3.5.0"
  eck_stack_version    = "0.20.0"
  elastic_version      = "9.5.4"
}
