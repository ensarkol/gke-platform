include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("google-provider.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform {
  source = "tfr:///terraform-google-modules/cloud-router/google?version=9.1.0"
}

dependency "vpc" {
  config_path = "../../vpc/gke-vpc"

  mock_outputs = {
    network_name = "test-vpc"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

inputs = {
  name    = "test-vpc-router"
  network = dependency.vpc.outputs.network_name

  nats = [
    {
      name                               = "test-vpc-nat"
      source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
      log_config = {
        enable = true
        filter = "ERRORS_ONLY"
      }
    },
  ]
}
