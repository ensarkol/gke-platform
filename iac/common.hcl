locals {
  project_id   = "test-devops-case"
  region       = "europe-west1"
  zone         = "europe-west1-b"
  cluster_name = "test-gke"

  artifact_registry_repo = "test"
  git_repo_url           = "https://github.com/ensarkol/gke-platform.git"


  allowed_cidrs = ["176.88.143.228/32", "78.189.234.89/32", "176.88.140.251/32"]
}
