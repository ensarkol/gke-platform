variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "cluster_name" {
  type    = string
  default = "test-gke"
}

variable "grafana_admin_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "alert_webhook_url" {
  description = "Webhook URL for Grafana pod restart alert contact point (optional)"
  type        = string
  default     = "http://localhost:9090"
}

variable "telegram_enabled" {
  description = "Send the pod restart alert to Telegram using TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID from the grafana-telegram secret; false keeps the webhook contact point"
  type        = bool
  default     = false
}

variable "kube_prometheus_stack_version" {
  type    = string
  default = "65.1.0"
}