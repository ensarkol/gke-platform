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

variable "gemini_model" {
  type    = string
  default = "gemini-2.0-flash"
}
