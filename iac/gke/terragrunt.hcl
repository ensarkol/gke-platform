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
  source = "tfr:///terraform-google-modules/kubernetes-engine/google?version=45.0.0"
}

dependency "vpc" {
  config_path = "../vpc/gke-vpc"

  mock_outputs = {
    network_name  = "test-vpc"
    subnets_names = ["test-subnet"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependencies {
  paths = ["../cloud-nat/gke-nat"]
}


inputs = {
  name     = local.common.cluster_name
  regional = false
  zones    = [local.common.zone]

  network           = dependency.vpc.outputs.network_name
  subnetwork        = dependency.vpc.outputs.subnets_names[0]
  ip_range_pods     = "pods"
  ip_range_services = "services"

  release_channel     = "REGULAR"
  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

  create_service_account = false
  service_account        = "default"

  http_load_balancing        = true
  horizontal_pod_autoscaling = true
  network_policy             = false
  dns_cache                  = true
  gce_pd_csi_driver          = true

  logging_enabled_components           = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  monitoring_enabled_components        = ["SYSTEM_COMPONENTS"]
  monitoring_enable_managed_prometheus = false

  security_posture_mode               = "BASIC"
  security_posture_vulnerability_mode = "VULNERABILITY_MODE_UNSPECIFIED"

  # Modülün node metadata'sına eklediği cluster_name/node_pool anahtarları node pool'u yeniden yaratır
  enable_default_node_pools_metadata = false

  node_pools = [
    {
      name               = "main-pool"
      machine_type       = "e2-standard-4"
      min_count          = 1
      max_count          = 3
      initial_node_count = 1
      disk_size_gb       = 50
      disk_type          = "pd-balanced"
      auto_repair        = true
      auto_upgrade       = true
    },
    {
      name               = "application-pool"
      machine_type       = "e2-medium"
      min_count          = 3
      max_count          = 5
      initial_node_count = 3
      disk_size_gb       = 40
      disk_type          = "pd-balanced"
      auto_repair        = true
      auto_upgrade       = true
    },
  ]

  node_pools_labels = {
    all              = {}
    main-pool        = { pool = "main" }
    application-pool = { pool = "application" }
  }

  node_pools_taints = {
    all       = []
    main-pool = []
    application-pool = [
      { key = "dedicated", value = "application", effect = "NO_SCHEDULE" },
    ]
  }

  node_pools_oauth_scopes = {
    all = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}
