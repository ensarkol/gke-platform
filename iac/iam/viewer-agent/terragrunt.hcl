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
  source = "tfr:///terraform-google-modules/kubernetes-engine/google//modules/workload-identity?version=45.0.0"
}

dependencies {
  paths = ["../../apis"]
}

inputs = {
  name                = "viewer-agent"
  namespace           = "agent"
  gcp_sa_display_name = "Viewer analysis agent"
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false

  roles = [
    "roles/viewer",
    "roles/aiplatform.user",
    "roles/logging.viewer",
    "roles/monitoring.viewer",
  ]
}
