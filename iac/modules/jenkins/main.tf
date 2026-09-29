terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_service_account" "jenkins" {
  account_id   = "jenkins-ci"
  display_name = "Jenkins CI/CD"
}

resource "google_project_iam_member" "jenkins_roles" {
  for_each = toset(var.roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "random_password" "jenkins_admin" {
  length  = 24
  special = false
}

resource "google_compute_instance" "jenkins" {
  name         = "jenkins"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.network_tags

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 50
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnetwork_id
    access_config {}
  }

  service_account {
    email  = google_service_account.jenkins.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin         = "TRUE"
    project-id             = var.project_id
    region                 = var.region
    artifact-registry-repo = var.artifact_registry_repo
    git-repo-url           = var.git_repo_url
    jenkins-admin-password = random_password.jenkins_admin.result
  }

  metadata_startup_script = var.startup_script

  allow_stopping_for_update = true

  depends_on = [google_project_iam_member.jenkins_roles]
}
