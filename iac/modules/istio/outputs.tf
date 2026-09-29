output "istio_system_namespace" {
  value = kubernetes_namespace.istio_system.metadata[0].name
}

output "apps_namespace" {
  value = kubernetes_namespace.apps.metadata[0].name
}

output "istio_version" {
  value = var.istio_version
}
