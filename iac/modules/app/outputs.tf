output "release_name" {
  value = helm_release.nodejs_app.name
}

output "image" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}/nodejs-app:${var.image_tag}"
}

output "app_url" {
  value = "http://${local.app_host}/"
}
