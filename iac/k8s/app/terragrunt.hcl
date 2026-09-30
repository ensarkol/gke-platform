include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//app"
}

dependency "gke" {
  config_path = "../../gke"

  mock_outputs = {
    name = "test-gke"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependencies {
  paths = ["../istio", "../keda", "../prometheus-stack"]
}

inputs = {
  cluster_name           = dependency.gke.outputs.name
  apps_namespace         = "apps"
  artifact_registry_repo = local.common.artifact_registry_repo
  chart_path             = "${get_parent_terragrunt_dir()}/../helm/nodejs-app"
  image_tag              = get_env("IMAGE_TAG", "latest")
}
