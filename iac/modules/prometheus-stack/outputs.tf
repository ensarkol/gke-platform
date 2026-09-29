output "monitoring_namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_admin_password" {
  value     = local.grafana_admin_password
  sensitive = true
}

output "prometheus_svc" {
  value = "kube-prometheus-stack-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc:9090"
}

output "grafana_port_forward" {
  value = "kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80"
}