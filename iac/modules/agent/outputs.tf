output "agent_namespace" {
  value = kubernetes_namespace.agent.metadata[0].name
}

output "agent_service_account" {
  value = google_service_account.agent.email
}

output "agent_image" {
  value = local.agent_image
}

output "port_forward" {
  value = "kubectl -n agent port-forward svc/viewer-agent 8080:80"
}

output "build_command" {
  value = "docker build -t ${local.agent_image} agent/ && docker push ${local.agent_image}"
}
