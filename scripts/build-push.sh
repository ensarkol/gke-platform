#!/usr/bin/env bash
# Build and push sample app + agent images
set -euo pipefail
cd "$(dirname "$0")/.."

hcl() { sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"([^\"]*)\".*/\1/p" iac/common.hcl | head -1; }

PROJECT_ID="${PROJECT_ID:-$(hcl project_id)}"
REGION="${REGION:-$(hcl region)}"
REPO="${ARTIFACT_REGISTRY_REPO:-$(hcl artifact_registry_repo)}"
TAG="${IMAGE_TAG:-latest}"
# GKE nodes are amd64; building on Apple Silicon would otherwise produce arm64 images
PLATFORM="${PLATFORM:-linux/amd64}"

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

APP_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/nodejs-app:${TAG}"
AGENT_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/viewer-agent:${TAG}"

docker buildx build --platform "$PLATFORM" -t "$APP_IMAGE" -f app/Dockerfile app/ --push
docker buildx build --platform "$PLATFORM" -t "$AGENT_IMAGE" -f agent/Dockerfile agent/ --push

echo "Pushed:"
echo "  $APP_IMAGE"
echo "  $AGENT_IMAGE"
