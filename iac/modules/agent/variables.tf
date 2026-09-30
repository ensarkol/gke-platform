variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "cluster_name" {
  type    = string
  default = "test-gke"
}

variable "artifact_registry_repo" {
  type    = string
  default = "test"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "grafana_url" {
  description = "Reachable Grafana URL for Terraform grafana provider (use port-forward or internal LB)"
  type        = string
  default     = "http://localhost:3000"
}

variable "gcp_service_account_email" {
  description = "GCP SA the agent KSA impersonates via Workload Identity (created in iac/iam/viewer-agent)"
  type        = string
}

variable "gemini_model" {
  type    = string
  default = "gemini-3.5-flash"
}

variable "gemini_location" {
  description = "Vertex AI location for Gemini; 3.x models are served from global / eu, not europe-west1"
  type        = string
  default     = "global"
}
