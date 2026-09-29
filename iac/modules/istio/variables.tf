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

variable "istio_version" {
  description = "Istio Helm chart version"
  type        = string
  default     = "1.30.5"
}

variable "apps_namespace" {
  type    = string
  default = "apps"
}
