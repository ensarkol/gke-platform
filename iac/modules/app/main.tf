resource "helm_release" "nodejs_app" {
  name      = "nodejs-app"
  chart     = var.chart_path
  namespace = var.apps_namespace
  wait      = true
  timeout   = 600

  values = [
    yamlencode({
      image = {
        repository = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}/nodejs-app"
        tag        = var.image_tag
      }
    })
  ]
}
