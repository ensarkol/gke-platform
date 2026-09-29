output "jenkins_external_ip" {
  value = google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip
}

output "jenkins_url" {
  value = "http://${google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip}:8080"
}

output "jenkins_admin_password" {
  value     = random_password.jenkins_admin.result
  sensitive = true
}

output "jenkins_service_account" {
  value = google_service_account.jenkins.email
}
