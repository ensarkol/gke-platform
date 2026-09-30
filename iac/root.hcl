locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

terraform_binary = "terraform"

remote_state {
  backend = "gcs"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    project  = local.common.project_id
    location = local.common.region
    bucket   = "${local.common.project_id}-tfstate"
    prefix   = path_relative_to_include()
  }
}

inputs = {
  project_id = local.common.project_id
  region     = local.common.region
  zone       = local.common.zone
}
