#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
META="http://metadata.google.internal/computeMetadata/v1/instance/attributes"
H=( -H "Metadata-Flavor: Google" )

PROJECT_ID=$(curl -sf "${H[@]}" "$META/project-id")
REGION=$(curl -sf "${H[@]}" "$META/region")
ARTIFACT_REGISTRY_REPO=$(curl -sf "${H[@]}" "$META/artifact-registry-repo")
GIT_REPO_URL=$(curl -sf "${H[@]}" "$META/git-repo-url" || true)
ADMIN_PASSWORD_SECRET=$(curl -sf "${H[@]}" "$META/admin-password-secret")
EXTERNAL_IP=$(curl -sf "${H[@]}" "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip")

export PROJECT_ID REGION ARTIFACT_REGISTRY_REPO GIT_REPO_URL EXTERNAL_IP

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release \
  software-properties-common unzip git jq python3

HOME_DISK=/dev/disk/by-id/google-jenkins-home
for _ in $(seq 1 30); do [ -e "$HOME_DISK" ] && break; sleep 2; done
blkid "$HOME_DISK" >/dev/null || mkfs.ext4 -m 0 -F "$HOME_DISK"
mkdir -p /var/lib/jenkins
grep -q "$HOME_DISK" /etc/fstab || echo "$HOME_DISK /var/lib/jenkins ext4 defaults,nofail 0 2" >> /etc/fstab
mountpoint -q /var/lib/jenkins || mount /var/lib/jenkins

install -m 0755 -d /etc/apt/keyrings
. /etc/os-release

curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --batch --yes --dearmor -o /etc/apt/keyrings/adoptium.gpg
echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb ${VERSION_CODENAME} main" \
  > /etc/apt/sources.list.d/adoptium.list
apt-get update
apt-get install -y temurin-21-jdk

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  > /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update
apt-get install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
. /etc/os-release
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update
apt-get install -y terraform

TERRAGRUNT_VERSION="v0.80.2"
curl -fsSL -o /usr/local/bin/terragrunt \
  "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
chmod +x /usr/local/bin/terragrunt

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  > /etc/apt/sources.list.d/jenkins.list
apt-get update
apt-get install -y jenkins
usermod -aG docker jenkins
systemctl stop jenkins || true

mkdir -p /var/lib/jenkins/casc_configs /opt/test
install -d -m 0700 -o jenkins -g jenkins /var/lib/jenkins/casc_secrets

for _ in $(seq 1 30); do
  gcloud secrets versions access latest --secret="$ADMIN_PASSWORD_SECRET" --project="$PROJECT_ID" \
    > /var/lib/jenkins/casc_secrets/JENKINS_ADMIN_PASSWORD 2>/dev/null && break
  sleep 10
done
test -s /var/lib/jenkins/casc_secrets/JENKINS_ADMIN_PASSWORD
chown jenkins:jenkins /var/lib/jenkins/casc_secrets/JENKINS_ADMIN_PASSWORD
chmod 0400 /var/lib/jenkins/casc_secrets/JENKINS_ADMIN_PASSWORD

mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djenkins.install.runSetupWizard=false"
Environment="CASC_JENKINS_CONFIG=/var/lib/jenkins/casc_configs"
Environment="SECRETS=/var/lib/jenkins/casc_secrets"
Environment="PROJECT_ID=${PROJECT_ID}"
Environment="REGION=${REGION}"
Environment="ARTIFACT_REGISTRY_REPO=${ARTIFACT_REGISTRY_REPO}"
Environment="GIT_REPO_URL=${GIT_REPO_URL}"
Environment="USE_GKE_GCLOUD_AUTH_PLUGIN=True"
EOF
chmod 600 /etc/systemd/system/jenkins.service.d/override.conf

cat > /opt/test/env.sh <<EOF
export PROJECT_ID=${PROJECT_ID}
export REGION=${REGION}
export ARTIFACT_REGISTRY_REPO=${ARTIFACT_REGISTRY_REPO}
export GIT_REPO_URL=${GIT_REPO_URL}
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
EOF

python3 <<'PY'
import os
from pathlib import Path

project = os.environ["PROJECT_ID"]
region = os.environ["REGION"]
git_repo = os.environ.get("GIT_REPO_URL", "")
ar_repo = os.environ.get("ARTIFACT_REGISTRY_REPO", "test")
external_ip = os.environ["EXTERNAL_IP"]

casc = f"""
jenkins:
  systemMessage: "GKE Platform - Jenkins"
  numExecutors: 2
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${{JENKINS_ADMIN_PASSWORD}}"
  authorizationStrategy:
    globalMatrix:
      entries:
        - user:
            name: "admin"
            permissions:
              - "Overall/Administer"
        - group:
            name: "authenticated"
            permissions:
              - "Overall/Read"
              - "Job/Read"

unclassified:
  location:
    url: "http://{external_ip}:8080/"

jobs:
  - script: |
      pipelineJob('01-gke-cluster') {{
        parameters {{
          choiceParam('ACTION', ['plan', 'apply', 'destroy'], 'Terraform action')
          stringParam('PROJECT_ID', '{project}', 'GCP project ID')
          stringParam('REGION', '{region}', 'GCP region')
          stringParam('ZONE', 'europe-west1-b', 'GCP zone')
          stringParam('CLUSTER_NAME', 'test-gke', 'GKE cluster name')
          stringParam('GIT_REPO_URL', '{git_repo}', 'Git repository URL')
        }}
        definition {{
          cpsScm {{
            scm {{
              git {{
                remote {{ url('{git_repo}') }}
                branches('*/main')
              }}
            }}
            scriptPath('jenkins/Jenkinsfile.gke')
          }}
        }}
      }}

  - script: |
      pipelineJob('02-istio') {{
        parameters {{
          choiceParam('ACTION', ['plan', 'apply', 'destroy'], 'Terraform action')
          stringParam('PROJECT_ID', '{project}', 'GCP project ID')
          stringParam('REGION', '{region}', 'GCP region')
          stringParam('ZONE', 'europe-west1-b', 'GCP zone')
          stringParam('CLUSTER_NAME', 'test-gke', 'GKE cluster name')
          stringParam('GIT_REPO_URL', '{git_repo}', 'Git repository URL')
        }}
        definition {{
          cpsScm {{
            scm {{
              git {{
                remote {{ url('{git_repo}') }}
                branches('*/main')
              }}
            }}
            scriptPath('jenkins/Jenkinsfile.istio')
          }}
        }}
      }}

  - script: |
      pipelineJob('03-nodejs-app') {{
        parameters {{
          choiceParam('ACTION', ['deploy', 'destroy'], 'Helm action')
          stringParam('PROJECT_ID', '{project}', 'GCP project ID')
          stringParam('REGION', '{region}', 'GCP region')
          stringParam('ZONE', 'europe-west1-b', 'GCP zone')
          stringParam('CLUSTER_NAME', 'test-gke', 'GKE cluster name')
          stringParam('IMAGE_TAG', '', 'Container image tag (empty = git commit SHA)')
          stringParam('GIT_REPO_URL', '{git_repo}', 'Git repository URL')
          stringParam('ARTIFACT_REGISTRY_REPO', '{ar_repo}', 'Artifact Registry repo')
        }}
        properties {{
          pipelineTriggers {{
            triggers {{
              pollSCM {{ scmpoll_spec('H/2 * * * *') }}
            }}
          }}
        }}
        definition {{
          cpsScm {{
            scm {{
              git {{
                remote {{ url('{git_repo}') }}
                branches('*/main')
                extensions {{
                  pathRestriction {{
                    includedRegions('(app/|helm/|iac/k8s/app/|iac/modules/app/|jenkins/Jenkinsfile[.]app).*')
                    excludedRegions('')
                  }}
                }}
              }}
            }}
            scriptPath('jenkins/Jenkinsfile.app')
          }}
        }}
      }}

  - script: |
      pipelineJob('04-viewer-agent') {{
        parameters {{
          choiceParam('ACTION', ['deploy', 'destroy'], 'Deploy action')
          stringParam('PROJECT_ID', '{project}', 'GCP project ID')
          stringParam('REGION', '{region}', 'GCP region')
          stringParam('ZONE', 'europe-west1-b', 'GCP zone')
          stringParam('CLUSTER_NAME', 'test-gke', 'GKE cluster name')
          stringParam('IMAGE_TAG', '', 'Container image tag (empty = git commit SHA)')
          stringParam('GIT_REPO_URL', '{git_repo}', 'Git repository URL')
          stringParam('ARTIFACT_REGISTRY_REPO', '{ar_repo}', 'Artifact Registry repo')
        }}
        definition {{
          cpsScm {{
            scm {{
              git {{
                remote {{ url('{git_repo}') }}
                branches('*/main')
              }}
            }}
            scriptPath('jenkins/Jenkinsfile.agent')
          }}
        }}
      }}
"""
Path("/var/lib/jenkins/casc_configs/jenkins.yaml").write_text(casc)
print("Wrote Casc config")
PY

mkdir -p /usr/share/jenkins/ref/plugins
cat > /usr/share/jenkins/ref/plugins.txt <<'PLUGINS'
configuration-as-code
job-dsl
matrix-auth
workflow-aggregator
git
timestamper
credentials-binding
pipeline-stage-view
ws-cleanup
PLUGINS

curl -fsSL -o /tmp/jenkins-plugin-manager.jar \
  https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.2/jenkins-plugin-manager-2.13.2.jar
java -jar /tmp/jenkins-plugin-manager.jar \
  --war /usr/share/java/jenkins.war \
  --plugin-file /usr/share/jenkins/ref/plugins.txt \
  --plugin-download-directory /var/lib/jenkins/plugins \
  --latest true || true

echo "2.0" > /var/lib/jenkins/jenkins.install.UpgradeWizard.state
echo "2.0" > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

chown -R jenkins:jenkins /var/lib/jenkins
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet || true

systemctl daemon-reload
systemctl enable docker
systemctl enable jenkins
systemctl restart jenkins

echo "Jenkins bootstrap complete" > /var/log/jenkins-bootstrap.done
