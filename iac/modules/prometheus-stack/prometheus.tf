resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  wait       = true
  timeout    = 900

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
          ruleSelectorNilUsesHelmValues           = false
          retention                               = "7d"
          resources = {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }
          nodeSelector = {
            "cloud.google.com/gke-nodepool" = "main-pool"
          }
        }
        # Chart creates these after its CRDs; kubernetes_manifest fails at plan time on a fresh cluster
        additionalServiceMonitors = [
          {
            name     = "istiod"
            selector = { matchLabels = { app = "istiod" } }
            # Istio dashboards query go_* metrics by {app="istiod"}
            targetLabels = ["app"]
            namespaceSelector = {
              matchNames = ["istio-system"]
            }
            endpoints = [
              {
                port     = "http-monitoring"
                interval = "15s"
                path     = "/metrics"
              }
            ]
          }
        ]
        additionalPodMonitors = [
          {
            name = "envoy-stats"
            selector = {
              matchExpressions = [
                { key = "istio-prometheus-ignore", operator = "DoesNotExist" }
              ]
            }
            namespaceSelector = { any = true }
            podMetricsEndpoints = [
              {
                port     = "http-envoy-prom"
                interval = "15s"
                path     = "/stats/prometheus"
                relabelings = [
                  {
                    action       = "keep"
                    regex        = "istio-proxy"
                    sourceLabels = ["__meta_kubernetes_pod_container_name"]
                  }
                ]
              }
            ]
          }
        ]
      }
      alertmanager = {
        enabled = true
        alertmanagerSpec = {
          nodeSelector = {
            "cloud.google.com/gke-nodepool" = "main-pool"
          }
        }
      }
      grafana = {
        enabled       = true
        adminPassword = local.grafana_admin_password
        nodeSelector = {
          "cloud.google.com/gke-nodepool" = "main-pool"
        }
        sidecar = {
          dashboards = {
            enabled = true
          }
        }
        additionalDataSources = []
        alerting = {
          # Keys become provisioning file names; Grafana skips files without a .yaml suffix
          "contactpoints.yaml" = yamldecode(<<-EOT
              apiVersion: 1
              contactPoints:
                - orgId: 1
                  name: pod-restart-webhook
                  receivers:
                    - uid: pod-restart-webhook
                      type: webhook
                      settings:
                        url: ${var.alert_webhook_url}
                      disableResolveMessage: false
            EOT
          )
          "policies.yaml" = yamldecode(<<-EOT
              apiVersion: 1
              policies:
                - orgId: 1
                  receiver: pod-restart-webhook
                  group_by:
                    - grafana_folder
                    - alertname
                  routes:
                    - receiver: pod-restart-webhook
                      object_matchers:
                        - ["alertname", "=", "PodRestartDetected"]
            EOT
          )
          "rules.yaml" = yamldecode(<<-EOT
              apiVersion: 1
              groups:
                - orgId: 1
                  name: kubernetes-pod-restarts
                  folder: Kubernetes
                  interval: 1m
                  rules:
                    - uid: pod-restart-alert
                      title: PodRestartDetected
                      condition: C
                      data:
                        - refId: A
                          relativeTimeRange:
                            from: 300
                            to: 0
                          datasourceUid: prometheus
                          model:
                            expr: increase(kube_pod_container_status_restarts_total[5m])
                            instant: true
                            intervalMs: 1000
                            maxDataPoints: 43200
                            refId: A
                        - refId: B
                          datasourceUid: __expr__
                          model:
                            conditions:
                              - evaluator:
                                  params: []
                                  type: gt
                                operator:
                                  type: and
                                query:
                                  params:
                                    - B
                                reducer:
                                  params: []
                                  type: last
                                type: query
                            datasource:
                              type: __expr__
                              uid: __expr__
                            expression: A
                            intervalMs: 1000
                            maxDataPoints: 43200
                            reducer: last
                            refId: B
                            type: reduce
                        - refId: C
                          datasourceUid: __expr__
                          model:
                            conditions:
                              - evaluator:
                                  params:
                                    - 0
                                  type: gt
                                operator:
                                  type: and
                                query:
                                  params:
                                    - C
                                reducer:
                                  params: []
                                  type: last
                                type: query
                            datasource:
                              type: __expr__
                              uid: __expr__
                            expression: B
                            intervalMs: 1000
                            maxDataPoints: 43200
                            refId: C
                            type: threshold
                      noDataState: NoData
                      execErrState: Error
                      for: 1m
                      annotations:
                        summary: "Pod restart detected"
                        description: "One or more pods restarted in the last 5 minutes."
                      labels:
                        severity: warning
                      isPaused: false
            EOT
          )
        }
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "istio"
                orgId           = 1
                folder          = "Istio"
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/istio"
                }
              }
            ]
          }
        }
        # Official Istio dashboards from grafana.com, downloaded by Grafana's init container
        dashboards = {
          istio = {
            for name, d in {
              istio-mesh          = { gnetId = 7639, revision = 333 }
              istio-service       = { gnetId = 7636, revision = 332 }
              istio-workload      = { gnetId = 7630, revision = 333 }
              istio-control-plane = { gnetId = 7645, revision = 332 }
              } : name => merge(d, {
                datasource = [{ name = "DS_PROMETHEUS", value = "Prometheus" }]
            })
          }
        }
      }
      prometheusOperator = {
        nodeSelector = {
          "cloud.google.com/gke-nodepool" = "main-pool"
        }
      }
      kube-state-metrics = {
        nodeSelector = {
          "cloud.google.com/gke-nodepool" = "main-pool"
        }
      }
      prometheus-node-exporter = {
        # Schedule on all nodes including tainted application-pool
        tolerations = [
          {
            operator = "Exists"
          }
        ]
      }
    })
  ]
}
