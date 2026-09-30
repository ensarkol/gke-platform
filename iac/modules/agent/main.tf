resource "kubernetes_namespace" "agent" {
  metadata {
    name = "agent"
    labels = {
      "istio-injection" = "enabled"
    }
  }
}

resource "kubernetes_service_account" "agent" {
  metadata {
    name      = "viewer-agent"
    namespace = kubernetes_namespace.agent.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = var.gcp_service_account_email
    }
  }
}

resource "kubernetes_cluster_role" "agent_viewer" {
  metadata {
    name = "viewer-agent"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "pods/status", "nodes", "nodes/status", "namespaces", "events", "services", "endpoints", "configmaps", "replicationcontrollers"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io", "networking.istio.io"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods", "nodes"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "agent_viewer" {
  metadata {
    name = "viewer-agent"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.agent_viewer.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.agent.metadata[0].name
    namespace = kubernetes_namespace.agent.metadata[0].name
  }
}

resource "grafana_service_account" "agent" {
  name        = "viewer-agent"
  role        = "Viewer"
  is_disabled = false
}

resource "grafana_service_account_token" "agent" {
  name               = "viewer-agent-token"
  service_account_id = grafana_service_account.agent.id
}

resource "kubernetes_secret" "grafana_token" {
  metadata {
    name      = "grafana-viewer-token"
    namespace = kubernetes_namespace.agent.metadata[0].name
  }

  data = {
    token = grafana_service_account_token.agent.key
  }

  type = "Opaque"
}

locals {
  agent_image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repo}/viewer-agent:${var.image_tag}"
}

resource "kubernetes_deployment" "agent" {
  metadata {
    name      = "viewer-agent"
    namespace = kubernetes_namespace.agent.metadata[0].name
    labels = {
      app = "viewer-agent"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "viewer-agent"
      }
    }
    template {
      metadata {
        labels = {
          app = "viewer-agent"
        }
      }
      spec {
        service_account_name = kubernetes_service_account.agent.metadata[0].name
        node_selector = {
          "cloud.google.com/gke-nodepool" = "main-pool"
        }
        container {
          name  = "viewer-agent"
          image = local.agent_image
          port {
            name           = "http"
            container_port = 8080
          }
          env {
            name  = "PROJECT_ID"
            value = var.project_id
          }
          env {
            name  = "REGION"
            value = var.region
          }
          env {
            name  = "ZONE"
            value = var.zone
          }
          env {
            name  = "CLUSTER_NAME"
            value = var.cluster_name
          }
          env {
            name  = "GEMINI_MODEL"
            value = var.gemini_model
          }
          env {
            name  = "GEMINI_LOCATION"
            value = var.gemini_location
          }
          env {
            name  = "GRAFANA_URL"
            value = "http://kube-prometheus-stack-grafana.monitoring.svc"
          }
          env {
            name = "GRAFANA_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_token.metadata[0].name
                key  = "token"
              }
            }
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
            initial_delay_seconds = 5
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = "http"
            }
            initial_delay_seconds = 10
          }
          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_secret.grafana_token]
}

resource "kubernetes_service" "agent" {
  metadata {
    name      = "viewer-agent"
    namespace = kubernetes_namespace.agent.metadata[0].name
    labels = {
      app = "viewer-agent"
    }
  }
  spec {
    selector = {
      app = "viewer-agent"
    }
    port {
      name        = "http"
      port        = 80
      target_port = 8080
    }
  }
}
