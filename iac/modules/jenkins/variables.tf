variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnetwork_id" {
  description = "Subnet the Jenkins VM is attached to"
  type        = string
}

variable "network_tags" {
  description = "Tags matched by the VPC firewall rules"
  type        = list(string)
  default     = ["jenkins"]
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "jenkins_home_disk_size" {
  description = "Size in GB of the persistent disk mounted at /var/lib/jenkins"
  type        = number
  default     = 20
}

variable "roles" {
  type = list(string)
}

variable "artifact_registry_repo" {
  type = string
}

variable "git_repo_url" {
  description = "Git repository URL cloned by Jenkins pipelines"
  type        = string
  default     = ""
}

variable "startup_script" {
  description = "Content of the VM startup script"
  type        = string
}
