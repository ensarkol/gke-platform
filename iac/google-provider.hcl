# Registry modülleri provider bloğu içermez; bu dosyayı include eden unit'lere provider.tf üretilir.
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project = "${local.common.project_id}"
      region  = "${local.common.region}"
    }

    provider "google-beta" {
      project = "${local.common.project_id}"
      region  = "${local.common.region}"
    }
  EOF
}
