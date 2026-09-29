resource "kubernetes_namespace" "keda" {
  metadata {
    name = "keda"
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.keda_version
  namespace  = kubernetes_namespace.keda.metadata[0].name
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      nodeSelector = {
        "cloud.google.com/gke-nodepool" = "main-pool"
      }
      operator = {
        nodeSelector = {
          "cloud.google.com/gke-nodepool" = "main-pool"
        }
      }
      metricsServer = {
        nodeSelector = {
          "cloud.google.com/gke-nodepool" = "main-pool"
        }
      }
      webhooks = {
        nodeSelector = {
          "cloud.google.com/gke-nodepool" = "main-pool"
        }
      }
    })
  ]
}
