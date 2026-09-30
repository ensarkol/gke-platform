include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "provider" {
  path = find_in_parent_folders("google-provider.hcl")
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

# GCP SA + project roles + Workload Identity binding for the viewer agent.
# Applied by hand: the Jenkins SA deliberately has no IAM admin rights, so it cannot grant roles.
# The k8s side (namespace, KSA, RBAC, deployment) lives in k8s/agent and is deployed by Jenkins.
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
