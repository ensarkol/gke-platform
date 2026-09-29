output "elastic_namespace" {
  value = kubernetes_namespace.elastic.metadata[0].name
}

output "elasticsearch_name" {
  value = "test-es"
}

output "kibana_port_forward" {
  value = "kubectl -n elastic-system port-forward svc/test-kb-kb-http 5601"
}

output "elastic_password_command" {
  value = "kubectl -n elastic-system get secret test-es-es-elastic-user -o go-template='{{.data.elastic | base64decode}}'"
}
