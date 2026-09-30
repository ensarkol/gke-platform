locals {
  project_id   = "test-devops-case"
  region       = "europe-west1"
  zone         = "europe-west1-b"
  cluster_name = "test-gke"

  artifact_registry_repo = "test"
  git_repo_url           = "https://github.com/ensarkol/gke-platform.git"
}
