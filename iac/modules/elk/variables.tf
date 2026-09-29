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

variable "eck_operator_version" {
  type    = string
  default = "2.14.0"
}

variable "elastic_version" {
  type    = string
  default = "8.15.0"
}
