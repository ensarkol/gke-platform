include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("google-provider.hcl")
}

locals {
  common        = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  allowed_cidrs = [for c in split(",", get_env("JENKINS_ALLOWED_CIDRS")) : trimspace(c)]
}

terraform {
  source = "tfr:///terraform-google-modules/network/google?version=18.3.0"
}

dependencies {
  paths = ["../../apis"]
}


inputs = {
  network_name = "jenkins-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "jenkins-subnet"
      subnet_ip             = "10.10.0.0/24"
      subnet_region         = local.common.region
      subnet_private_access = "true"
    },
  ]

  ingress_rules = [
    {
      name          = "jenkins-allow-ssh"
      source_ranges = local.allowed_cidrs
      target_tags   = ["jenkins"]
      allow         = [{ protocol = "tcp", ports = ["22"] }]
    },
    {
      name          = "jenkins-allow-ui"
      source_ranges = local.allowed_cidrs
      target_tags   = ["jenkins"]
      allow         = [{ protocol = "tcp", ports = ["8080"] }]
    },
  ]
}
