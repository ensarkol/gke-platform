terraform {
  required_version = ">= 1.11.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
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

ephemeral "random_password" "jenkins_admin" {
  length  = 24
  special = false
}

resource "google_secret_manager_secret" "jenkins_admin_password" {
  secret_id = "jenkins-admin-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "jenkins_admin_password" {
  secret                 = google_secret_manager_secret.jenkins_admin_password.id
  secret_data_wo         = ephemeral.random_password.jenkins_admin.result
  secret_data_wo_version = var.admin_password_version
}

resource "google_secret_manager_secret_iam_member" "jenkins_admin_password" {
  secret_id = google_secret_manager_secret.jenkins_admin_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.jenkins.email}"
}

resource "google_compute_disk" "jenkins_home" {
  name = "jenkins-home"
  zone = var.zone
  type = "pd-balanced"
  size = var.jenkins_home_disk_size
}

resource "google_compute_address" "jenkins" {
  name   = "jenkins"
  region = var.region
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

  attached_disk {
    source      = google_compute_disk.jenkins_home.id
    device_name = "jenkins-home"
  }

  network_interface {
    subnetwork = var.subnetwork_id
    access_config {
      nat_ip = google_compute_address.jenkins.address
    }
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
    admin-password-secret  = google_secret_manager_secret.jenkins_admin_password.secret_id
  }

  metadata_startup_script = var.startup_script

  allow_stopping_for_update = true

  depends_on = [
    google_project_iam_member.jenkins_roles,
    google_secret_manager_secret_version.jenkins_admin_password,
    google_secret_manager_secret_iam_member.jenkins_admin_password,
  ]
}
