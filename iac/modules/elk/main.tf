locals {
  main_pool = { "cloud.google.com/gke-nodepool" = "main-pool" }
}

resource "kubernetes_namespace" "elastic" {
  metadata {
    name = "elastic-system"
  }
}

resource "helm_release" "eck_operator" {
  name       = "eck-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = var.eck_operator_version
  namespace  = kubernetes_namespace.elastic.metadata[0].name
  wait       = true
  timeout    = 600

  values = [
    yamlencode({
      nodeSelector = local.main_pool
    })
  ]
}

resource "helm_release" "eck_stack" {
  name       = "eck-stack"
  repository = "https://helm.elastic.co"
  chart      = "eck-stack"
  version    = var.eck_stack_version
  namespace  = kubernetes_namespace.elastic.metadata[0].name
  timeout    = 600

  values = [
    yamlencode({
      eck-elasticsearch = {
        fullnameOverride = "test-es"
        version          = var.elastic_version
        nodeSets = [{
          name   = "default"
          count  = 1
          config = { "node.store.allow_mmap" = false }
          podTemplate = {
            spec = {
              nodeSelector = local.main_pool
              containers = [{
                name = "elasticsearch"
                resources = {
                  requests = { memory = "2Gi", cpu = "500m" }
                  limits   = { memory = "2Gi" }
                }
              }]
            }
          }
          volumeClaimTemplates = [{
            metadata = { name = "elasticsearch-data" }
            spec = {
              accessModes = ["ReadWriteOnce"]
              resources   = { requests = { storage = "20Gi" } }
            }
          }]
        }]
      }

      eck-kibana = {
        fullnameOverride = "test-kb"
        version          = var.elastic_version
        count            = 1
        elasticsearchRef = { name = "test-es" }
        podTemplate = {
          spec = {
            nodeSelector = local.main_pool
            containers = [{
              name = "kibana"
              resources = {
                requests = { memory = "1Gi", cpu = "200m" }
                limits   = { memory = "1Gi" }
              }
            }]
          }
        }
      }

      eck-beats = {
        enabled          = true
        fullnameOverride = "filebeat"
        type             = "filebeat"
        version          = var.elastic_version
        elasticsearchRef = { name = "test-es" }
        kibanaRef        = { name = "test-kb" }
        config = {
          filebeat = {
            inputs = [{
              type  = "filestream"
              id    = "kubernetes-container-logs"
              paths = ["/var/log/containers/*.log"]
              parsers = [{
                container = {}
              }]
              prospector = {
                scanner = { symlinks = true }
              }
              processors = [{
                add_kubernetes_metadata = {
                  host = "$${NODE_NAME}"
                  matchers = [{
                    logs_path = { logs_path = "/var/log/containers/" }
                  }]
                }
              }]
            }]
          }
          setup = {
            template = {
              overwrite = true
              settings  = { index = { number_of_replicas = 0 } }
            }
          }
        }
        daemonSet = {
          podTemplate = {
            spec = {
              serviceAccountName           = kubernetes_service_account.filebeat.metadata[0].name
              automountServiceAccountToken = true
              securityContext              = { runAsUser = 0 }
              tolerations                  = [{ operator = "Exists" }]
              containers = [{
                name = "filebeat"
                env = [{
                  name      = "NODE_NAME"
                  valueFrom = { fieldRef = { fieldPath = "spec.nodeName" } }
                }]
                resources = {
                  requests = { memory = "200Mi", cpu = "50m" }
                  limits   = { memory = "300Mi" }
                }
                volumeMounts = [
                  { name = "varlogcontainers", mountPath = "/var/log/containers", readOnly = true },
                  { name = "varlogpods", mountPath = "/var/log/pods", readOnly = true },
                ]
              }]
              volumes = [
                { name = "varlogcontainers", hostPath = { path = "/var/log/containers" } },
                { name = "varlogpods", hostPath = { path = "/var/log/pods" } },
              ]
            }
          }
        }
      }
    })
  ]

  depends_on = [
    helm_release.eck_operator,
    kubernetes_cluster_role_binding.filebeat,
  ]
}

resource "kubernetes_service_account" "filebeat" {
  metadata {
    name      = "filebeat"
    namespace = kubernetes_namespace.elastic.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "filebeat" {
  metadata {
    name = "filebeat"
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "nodes"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "filebeat" {
  metadata {
    name = "filebeat"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.filebeat.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.filebeat.metadata[0].name
    namespace = kubernetes_namespace.elastic.metadata[0].name
  }
}

resource "kubernetes_job" "kibana_dataview" {
  metadata {
    name      = "kibana-create-dataview"
    namespace = kubernetes_namespace.elastic.metadata[0].name
  }

  spec {
    backoff_limit = 20
    template {
      metadata {
        labels = {
          app = "kibana-dataview"
        }
      }
      spec {
        restart_policy = "OnFailure"
        node_selector  = local.main_pool
        container {
          name  = "curl"
          image = "curlimages/curl:8.10.1"
          env {
            name = "ELASTIC_PASSWORD"
            value_from {
              secret_key_ref {
                name = "test-es-es-elastic-user"
                key  = "elastic"
              }
            }
          }
          command = [
            "/bin/sh",
            "-c",
            <<-EOT
              set -eu
              for i in $(seq 1 60); do
                if curl -sk -u "elastic:$${ELASTIC_PASSWORD}" https://test-kb-kb-http.elastic-system.svc:5601/api/status | grep -qi '"overall".*"level".*"available"'; then
                  break
                fi
                echo "waiting for kibana..."
                sleep 10
              done
              curl -sk -u "elastic:$${ELASTIC_PASSWORD}" \
                -X POST "https://test-kb-kb-http.elastic-system.svc:5601/api/data_views/data_view" \
                -H "kbn-xsrf: true" \
                -H "Content-Type: application/json" \
                -d '{"data_view":{"title":"filebeat-*","name":"filebeat-logs","timeFieldName":"@timestamp"}}' \
                || true
              echo "data view step finished"
            EOT
          ]
        }
      }
    }
  }

  wait_for_completion = false

  depends_on = [helm_release.eck_stack]

  timeouts {
    create = "5m"
  }
}
