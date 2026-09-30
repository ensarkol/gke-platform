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
  default = "3.5.0"
}

variable "eck_stack_version" {
  type    = string
  default = "0.20.0"
}

variable "elastic_version" {
  type    = string
  default = "9.5.4"
}
