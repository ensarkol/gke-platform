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
  source = "tfr:///terraform-google-modules/network/google?version=18.3.0"
}

dependencies {
  paths = ["../../apis"]
}


inputs = {
  network_name = "test-vpc"
  routing_mode = "REGIONAL"

  subnets = [
    {
      subnet_name           = "test-subnet"
      subnet_ip             = "10.20.0.0/20"
      subnet_region         = local.common.region
      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    "test-subnet" = [
      { range_name = "pods", ip_cidr_range = "10.40.0.0/14" },
      { range_name = "services", ip_cidr_range = "10.60.0.0/20" },
    ]
  }
}
