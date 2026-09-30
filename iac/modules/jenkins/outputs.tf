output "jenkins_external_ip" {
  value = google_compute_address.jenkins.address
}

output "jenkins_url" {
  value = "http://${google_compute_address.jenkins.address}:8080"
}

output "admin_password_secret" {
  value = google_secret_manager_secret.jenkins_admin_password.secret_id
}

output "jenkins_service_account" {
  value = google_service_account.jenkins.email
}
