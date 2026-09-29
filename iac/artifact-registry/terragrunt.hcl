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
  source = "tfr:///GoogleCloudPlatform/artifact-registry/google?version=0.8.2"
}

dependencies {
  paths = ["../apis"]
}


inputs = {
  location      = local.common.region
  repository_id = local.common.artifact_registry_repo
  format        = "DOCKER"
  description   = "Container images for the GKE platform"
}
