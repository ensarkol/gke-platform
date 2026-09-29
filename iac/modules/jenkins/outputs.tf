output "jenkins_external_ip" {
  value = google_compute_address.jenkins.address
}

output "jenkins_url" {
  value = "http://${google_compute_address.jenkins.address}:8080"
}

output "jenkins_admin_password" {
  value     = random_password.jenkins_admin.result
  sensitive = true
}

output "jenkins_service_account" {
  value = google_service_account.jenkins.email
}
