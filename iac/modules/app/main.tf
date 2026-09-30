data "kubernetes_service" "istio_ingress" {
  metadata {
    name      = "istio-ingress"
    namespace = "istio-system"
  }
}

locals {
  ingress_ip = data.kubernetes_service.istio_ingress.status[0].load_balancer[0].ingress[0].ip
  # Bots scanning the bare LB IP would otherwise count as traffic and keep KEDA from idling to zero
  app_host = var.app_host != "" ? var.app_host : "${local.ingress_ip}.nip.io"
}

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
      istio = {
        hosts = [local.app_host]
      }
    })
  ]
}
