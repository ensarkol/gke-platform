include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "${get_parent_terragrunt_dir()}/modules//jenkins"
}

dependency "vpc" {
  config_path = "../vpc/jenkins-vpc"

  mock_outputs = {
    subnets_ids = ["mock"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "artifact_registry" {
  config_path = "../artifact-registry"

  mock_outputs = {
    artifact_name = "test"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  subnetwork_id          = dependency.vpc.outputs.subnets_ids[0]
  network_tags           = ["jenkins"]
  machine_type           = "e2-standard-2"
  artifact_registry_repo = dependency.artifact_registry.outputs.artifact_name
  git_repo_url           = local.common.git_repo_url
  startup_script         = file("${get_parent_terragrunt_dir()}/../jenkins/startup.sh")

  roles = [
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/storage.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",
    "roles/logging.logWriter",
  ]
}
