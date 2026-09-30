resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = var.apps_namespace
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  wait       = true
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  wait       = true
  timeout    = 600

  set {
    name  = "pilot.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "pilot.resources.requests.memory"
    value = "128Mi"
  }

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_ingress" {
  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      name = "istio-ingress"
      service = {
        type = "LoadBalancer"
      }
      labels = {
        istio = "ingress"
      }
      nodeSelector = {
        "cloud.google.com/gke-nodepool" = "main-pool"
      }
    })
  ]

  depends_on = [helm_release.istiod]
}

resource "helm_release" "istio_egress" {
  name       = "istio-egress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      name = "istio-egress"
      service = {
        type = "ClusterIP"
      }
      labels = {
        istio = "egress"
      }
      nodeSelector = {
        "cloud.google.com/gke-nodepool" = "main-pool"
      }
    })
  ]

  depends_on = [helm_release.istiod]
}
