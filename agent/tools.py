"""Read-only tools for GCP, Kubernetes and Grafana."""

from __future__ import annotations

import json
from typing import Any

import httpx
from google.cloud import compute_v1, container_v1, logging_v2
from kubernetes import client as k8s_client
from kubernetes import config as k8s_config

from config import settings


def _k8s():
    try:
        k8s_config.load_incluster_config()
    except k8s_config.ConfigException:
        k8s_config.load_kube_config()
    return k8s_client


def list_gke_clusters() -> str:
    client = container_v1.ClusterManagerClient()
    parent = f"projects/{settings.project_id}/locations/-"
    clusters = client.list_clusters(request={"parent": parent})
    result = []
    for c in clusters.clusters:
        result.append(
            {
                "name": c.name,
                "location": c.location,
                "status": container_v1.Cluster.Status(c.status).name,
                "node_count": c.current_node_count,
                "version": c.current_master_version,
            }
        )
    return json.dumps(result, indent=2)


def list_node_pools(cluster_name: str | None = None, location: str | None = None) -> str:
    cluster_name = cluster_name or settings.cluster_name
    location = location or settings.zone
    client = container_v1.ClusterManagerClient()
    parent = f"projects/{settings.project_id}/locations/{location}/clusters/{cluster_name}"
    response = client.list_node_pools(request={"parent": parent})
    result = []
    for np in response.node_pools:
        autoscaling = None
        if np.autoscaling and np.autoscaling.enabled:
            autoscaling = {
                "min": np.autoscaling.min_node_count,
                "max": np.autoscaling.max_node_count,
            }
        result.append(
            {
                "name": np.name,
                "status": container_v1.NodePool.Status(np.status).name,
                "initial_node_count": np.initial_node_count,
                "machine_type": np.config.machine_type if np.config else None,
                "autoscaling": autoscaling,
            }
        )
    return json.dumps(result, indent=2)


def list_compute_instances(zone: str | None = None) -> str:
    zone = zone or settings.zone
    client = compute_v1.InstancesClient()
    items = []
    for inst in client.list(project=settings.project_id, zone=zone):
        items.append(
            {
                "name": inst.name,
                "status": inst.status,
                "machine_type": inst.machine_type.split("/")[-1],
                "zone": zone,
            }
        )
    return json.dumps(items, indent=2)


def query_cloud_logging(filter_str: str, page_size: int = 20) -> str:
    client = logging_v2.Client(project=settings.project_id)
    entries = []
    for entry in client.list_entries(filter_=filter_str, page_size=page_size, max_results=page_size):
        entries.append(
            {
                "timestamp": str(entry.timestamp),
                "severity": entry.severity,
                "resource": entry.resource.type if entry.resource else None,
                "payload": str(entry.payload)[:500],
            }
        )
    return json.dumps(entries, indent=2)


def list_k8s_pods(namespace: str = "") -> str:
    v1 = _k8s().CoreV1Api()
    if namespace:
        pods = v1.list_namespaced_pod(namespace)
    else:
        pods = v1.list_pod_for_all_namespaces()
    result = []
    for p in pods.items:
        result.append(
            {
                "namespace": p.metadata.namespace,
                "name": p.metadata.name,
                "phase": p.status.phase,
                "node": p.spec.node_name,
                "restarts": sum(
                    (c.restart_count or 0) for c in (p.status.container_statuses or [])
                ),
            }
        )
    return json.dumps(result, indent=2)


def list_k8s_deployments(namespace: str = "") -> str:
    apps = _k8s().AppsV1Api()
    if namespace:
        deps = apps.list_namespaced_deployment(namespace)
    else:
        deps = apps.list_deployment_for_all_namespaces()
    result = []
    for d in deps.items:
        result.append(
            {
                "namespace": d.metadata.namespace,
                "name": d.metadata.name,
                "replicas": d.spec.replicas,
                "ready": d.status.ready_replicas,
                "available": d.status.available_replicas,
            }
        )
    return json.dumps(result, indent=2)


def list_k8s_nodes() -> str:
    v1 = _k8s().CoreV1Api()
    nodes = v1.list_node()
    result = []
    for n in nodes.items:
        labels = n.metadata.labels or {}
        result.append(
            {
                "name": n.metadata.name,
                "ready": any(
                    c.type == "Ready" and c.status == "True"
                    for c in (n.status.conditions or [])
                ),
                "pool": labels.get("cloud.google.com/gke-nodepool"),
                "instance_type": labels.get("node.kubernetes.io/instance-type"),
            }
        )
    return json.dumps(result, indent=2)


def list_k8s_events(namespace: str = "default", limit: int = 30) -> str:
    v1 = _k8s().CoreV1Api()
    events = v1.list_namespaced_event(namespace, limit=limit)
    result = []
    for e in sorted(events.items, key=lambda x: x.last_timestamp or x.event_time or "", reverse=True)[:limit]:
        result.append(
            {
                "type": e.type,
                "reason": e.reason,
                "object": f"{e.involved_object.kind}/{e.involved_object.name}",
                "message": e.message,
                "count": e.count,
            }
        )
    return json.dumps(result, indent=2)


def get_pod_logs(namespace: str, pod_name: str, container: str | None = None, tail: int = 100) -> str:
    v1 = _k8s().CoreV1Api()
    kwargs: dict[str, Any] = {"name": pod_name, "namespace": namespace, "tail_lines": tail}
    if container:
        kwargs["container"] = container
    logs = v1.read_namespaced_pod_log(**kwargs)
    return logs[-8000:] if logs else "(empty)"


def grafana_list_dashboards(query: str = "") -> str:
    headers = {"Authorization": f"Bearer {settings.grafana_token}"}
    with httpx.Client(base_url=settings.grafana_url, headers=headers, timeout=30.0) as client:
        r = client.get("/api/search", params={"query": query, "type": "dash-db"})
        r.raise_for_status()
        return json.dumps(r.json(), indent=2)


def grafana_list_alerts() -> str:
    headers = {"Authorization": f"Bearer {settings.grafana_token}"}
    with httpx.Client(base_url=settings.grafana_url, headers=headers, timeout=30.0) as client:
        r = client.get("/api/prometheus/grafana/api/v1/rules")
        if r.status_code >= 400:
            r = client.get("/api/alerts")
        r.raise_for_status()
        return json.dumps(r.json(), indent=2)[:12000]


def grafana_promql(query: str) -> str:
    headers = {"Authorization": f"Bearer {settings.grafana_token}"}
    with httpx.Client(base_url=settings.grafana_url, headers=headers, timeout=30.0) as client:
        # Use datasource proxy – assume prometheus datasource uid 'prometheus'
        r = client.get(
            "/api/datasources/proxy/uid/prometheus/api/v1/query",
            params={"query": query},
        )
        if r.status_code >= 400:
            # fallback: list datasources and use numeric id
            ds = client.get("/api/datasources")
            ds.raise_for_status()
            prom = next((d for d in ds.json() if d.get("type") == "prometheus"), None)
            if not prom:
                return json.dumps({"error": "prometheus datasource not found"})
            r = client.get(
                f"/api/datasources/proxy/{prom['id']}/api/v1/query",
                params={"query": query},
            )
        r.raise_for_status()
        return json.dumps(r.json(), indent=2)[:12000]


TOOL_DECLARATIONS = [
    {
        "name": "list_gke_clusters",
        "description": "List GKE clusters in the GCP project (viewer).",
        "parameters": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "list_node_pools",
        "description": "List node pools for a GKE cluster.",
        "parameters": {
            "type": "object",
            "properties": {
                "cluster_name": {"type": "string"},
                "location": {"type": "string"},
            },
            "required": [],
        },
    },
    {
        "name": "list_compute_instances",
        "description": "List Compute Engine VMs in a zone.",
        "parameters": {
            "type": "object",
            "properties": {"zone": {"type": "string"}},
            "required": [],
        },
    },
    {
        "name": "query_cloud_logging",
        "description": "Query Cloud Logging with a filter expression.",
        "parameters": {
            "type": "object",
            "properties": {
                "filter_str": {"type": "string", "description": "Cloud Logging filter"},
                "page_size": {"type": "integer"},
            },
            "required": ["filter_str"],
        },
    },
    {
        "name": "list_k8s_pods",
        "description": "List Kubernetes pods (optionally filtered by namespace).",
        "parameters": {
            "type": "object",
            "properties": {"namespace": {"type": "string"}},
            "required": [],
        },
    },
    {
        "name": "list_k8s_deployments",
        "description": "List Kubernetes deployments.",
        "parameters": {
            "type": "object",
            "properties": {"namespace": {"type": "string"}},
            "required": [],
        },
    },
    {
        "name": "list_k8s_nodes",
        "description": "List Kubernetes nodes and their node pools.",
        "parameters": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "list_k8s_events",
        "description": "List recent Kubernetes events in a namespace.",
        "parameters": {
            "type": "object",
            "properties": {
                "namespace": {"type": "string"},
                "limit": {"type": "integer"},
            },
            "required": [],
        },
    },
    {
        "name": "get_pod_logs",
        "description": "Read stdout logs from a pod (no secrets).",
        "parameters": {
            "type": "object",
            "properties": {
                "namespace": {"type": "string"},
                "pod_name": {"type": "string"},
                "container": {"type": "string"},
                "tail": {"type": "integer"},
            },
            "required": ["namespace", "pod_name"],
        },
    },
    {
        "name": "grafana_list_dashboards",
        "description": "Search Grafana dashboards (viewer).",
        "parameters": {
            "type": "object",
            "properties": {"query": {"type": "string"}},
            "required": [],
        },
    },
    {
        "name": "grafana_list_alerts",
        "description": "List Grafana alert rules / alert status.",
        "parameters": {"type": "object", "properties": {}, "required": []},
    },
    {
        "name": "grafana_promql",
        "description": "Run a PromQL instant query via Grafana datasource proxy.",
        "parameters": {
            "type": "object",
            "properties": {"query": {"type": "string"}},
            "required": ["query"],
        },
    },
]

TOOL_IMPL = {
    "list_gke_clusters": lambda **_: list_gke_clusters(),
    "list_node_pools": lambda **kw: list_node_pools(**kw),
    "list_compute_instances": lambda **kw: list_compute_instances(**kw),
    "query_cloud_logging": lambda **kw: query_cloud_logging(**kw),
    "list_k8s_pods": lambda **kw: list_k8s_pods(**kw),
    "list_k8s_deployments": lambda **kw: list_k8s_deployments(**kw),
    "list_k8s_nodes": lambda **_: list_k8s_nodes(),
    "list_k8s_events": lambda **kw: list_k8s_events(**kw),
    "get_pod_logs": lambda **kw: get_pod_logs(**kw),
    "grafana_list_dashboards": lambda **kw: grafana_list_dashboards(**kw),
    "grafana_list_alerts": lambda **_: grafana_list_alerts(),
    "grafana_promql": lambda **kw: grafana_promql(**kw),
}


def run_tool(name: str, args: dict[str, Any]) -> str:
    fn = TOOL_IMPL.get(name)
    if not fn:
        return json.dumps({"error": f"unknown tool {name}"})
    try:
        # Drop None values
        clean = {k: v for k, v in (args or {}).items() if v is not None}
        return fn(**clean)
    except Exception as exc:  # noqa: BLE001
        return json.dumps({"error": str(exc)})
