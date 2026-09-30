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

variable "apps_namespace" {
  description = "Created by the k8s/istio layer with istio-injection=enabled"
  type        = string
  default     = "apps"
}

variable "artifact_registry_repo" {
  type    = string
  default = "test"
}

variable "chart_path" {
  description = "Local path to the nodejs-app Helm chart"
  type        = string
}

variable "app_host" {
  description = "Host name the Gateway accepts; empty = <ingress IP>.nip.io"
  type        = string
  default     = ""
}

variable "image_tag" {
  type    = string
  default = "latest"
}
