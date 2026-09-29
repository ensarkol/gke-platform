#!/usr/bin/env bash
# Helper: get cluster credentials
set -euo pipefail
PROJECT_ID="${PROJECT_ID:?set PROJECT_ID}"
ZONE="${ZONE:-europe-west1-b}"
CLUSTER_NAME="${CLUSTER_NAME:-test-gke}"
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE" --project "$PROJECT_ID"
