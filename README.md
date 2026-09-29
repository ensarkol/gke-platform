# GKE Platform

Infrastructure-as-Code (Terragrunt + Terraform + Helm) ile GKE üzerinde örnek Node.js uygulaması, Istio, Prometheus/Grafana, KEDA, ELK ve viewer yetkili analiz agent'ı.

> Bu repo **kodu hazırlar**. `terragrunt apply` ve image push işlemlerini kendi GCP projenizde çalıştırmanız beklenir.

## Yapı

Her kaynak kendi klasöründe, kendi `terragrunt.hcl`'i ve kendi state'i ile durur. Hangisini kurmak istiyorsan onun klasörüne girip `terragrunt apply` çalıştırırsın.

```text
iac/
  common.hcl                     # project_id, region, zone, cluster_name, allowed_cidr
  root.hcl                       # GCS remote state + ortak input'lar
  google-provider.hcl            # Registry modülleri için google/google-beta provider'ı üretir
  apis/                          # Google API'leri
  artifact-registry/             # Docker image repo'su (test)
  vpc/
    jenkins-vpc/                 # jenkins-vpc, jenkins-subnet 10.10.0.0/24, firewall 22/8080
    gke-vpc/                     # test-vpc, test-subnet 10.20.0.0/20 (+pods/services)
  cloud-nat/
    gke-nat/                     # test-vpc-router + test-vpc-nat (GKE node'larının internet çıkışı)
  jenkins/                       # Jenkins VM + service account
  gke/                           # test-gke: main-pool + application-pool (autoscaling, taint)
  k8s/
    istio/                       # istiod, istio-ingress, istio-egress, apps namespace
    prometheus-stack/            # kube-prometheus-stack, Istio scrape, Grafana pod restart alarmı
    keda/                        # KEDA operator (ScaledObject CRD)
    elk/                         # ECK: Elasticsearch, Kibana, Filebeat, data view
    app/                         # helm/nodejs-app chart'ı (helm_release)
    agent/                       # Viewer agent (Vertex AI Gemini)
  modules/                       # Hazır karşılığı olmayan kendi modüllerimiz (apply edilmez)
    jenkins/ istio/ prometheus-stack/ keda/ elk/ app/ agent/
app/                             # Express + /metrics
helm/nodejs-app/                 # Deployment, Gateway, VirtualService, ScaledObject
jenkins/                         # startup.sh + Jenkinsfile'lar
agent/                           # FastAPI + Gemini viewer agent
```

GCP kaynakları Google'ın resmi Terraform modülleriyle kurulur:

| Klasör | Modül |
|---|---|
| `apis/` | `terraform-google-modules/project-factory/google//modules/project_services` 18.3.0 |
| `artifact-registry/` | `GoogleCloudPlatform/artifact-registry/google` 0.8.2 |
| `vpc/*` | `terraform-google-modules/network/google` 18.3.0 |
| `cloud-nat/gke-nat` | `terraform-google-modules/cloud-router/google` 9.1.0 |
| `gke/` | `terraform-google-modules/kubernetes-engine/google` 45.0.0 |

VPC adı, subnet CIDR'ları, secondary range'ler ve firewall kuralları doğrudan ilgili klasördeki `terragrunt.hcl` içinde görünür.

State: `gs://test-devops-case-tfstate/<unit-yolu>/default.tfstate` (örn. `vpc/gke-vpc`, `gke`, `k8s/istio`). Bucket yoksa Terragrunt ilk çalıştırmada oluşturmayı önerir.

Bağımlılıklar (`dependency` blokları) Terragrunt tarafından çözülür. Örneğin `gke`, `vpc/gke-vpc`'nin network ve subnet output'larını okur.

```text
apis ─┬─ artifact-registry ─┐
      ├─ vpc/jenkins-vpc ───┴─ jenkins
      └─ vpc/gke-vpc ── cloud-nat/gke-nat ── gke ─┬─ k8s/istio ── k8s/prometheus-stack ─┬─ k8s/app
                                                  │                                     └─ k8s/agent
                                                  ├─ k8s/keda ─────────────────────────── k8s/app
                                                  └─ k8s/elk
```

## Önkoşullar

- GCP projesi ve faturalandırma
- Yerel araçlar: `gcloud`, `terraform` (>= 1.5), `terragrunt` (>= 0.80), `kubectl`, `helm`, `docker`
- `gcloud auth login` ve `gcloud auth application-default login`
- Farklı bir proje kullanacaksan `iac/common.hcl` içini güncelle

## Kurulum

Tek tek (önerilen, her adımı görerek):

```bash
cd iac/apis                && terragrunt apply
cd ../artifact-registry    && terragrunt apply
cd ../vpc/jenkins-vpc      && terragrunt apply
cd ../gke-vpc              && terragrunt apply
cd ../../cloud-nat/gke-nat && terragrunt apply
cd ../../jenkins           && terragrunt apply
cd ../gke                  && terragrunt apply
```

Ya da hepsi bağımlılık sırasıyla:

```bash
cd iac
terragrunt run --all apply
```

Bir klasörün altındakileri toplu kurmak için de aynı komut çalışır. Örneğin `cd iac/vpc && terragrunt run --all apply` iki VPC'yi birlikte kurar.

### Jenkins

```bash
cd iac/jenkins
terragrunt output -raw jenkins_url
terragrunt output -raw jenkins_admin_password
```

VM ilk açılışta (5-10 dk) docker, gcloud, kubectl, helm, terraform, terragrunt ve Jenkins'i kurar.

| Job | Ne yapar |
|-----|----------|
| `01-gke-cluster` | `iac/vpc/gke-vpc` + `iac/cloud-nat/gke-nat` + `iac/gke` plan / apply / destroy |
| `02-istio` | `iac/k8s/istio` plan / apply / destroy |
| `03-nodejs-app` | `nodejs-app` image build+push + `iac/k8s/app` (Helm) deploy / destroy |
| `04-viewer-agent` | `viewer-agent` image build+push + `iac/k8s/agent` deploy / destroy (Grafana port-forward'u pipeline açar) |

Image tag'i boş bırakılırsa git commit SHA'sı kullanılır; her commit yeni bir tag üretir ve pod'lar yeni image'a geçer.

Pipeline'lar repo'yu `git_repo_url`'den çeker. Bunu `common.hcl` içine yazıp `jenkins` unit'ini tekrar apply et.

### GKE doğrulama

```bash
gcloud container clusters get-credentials test-gke --zone europe-west1-b --project test-devops-case
kubectl get nodes -L cloud.google.com/gke-nodepool
```

Beklenen: `main-pool` ve `application-pool` node'ları; application-pool üzerinde `dedicated=application:NoSchedule` taint.

### Istio

```bash
cd iac/k8s/istio && terragrunt apply
kubectl -n istio-system get pods,svc
```

### KEDA

```bash
cd iac/k8s/keda && terragrunt apply
kubectl -n keda get pods
```

### Prometheus stack (Prometheus + Grafana alarm)

```bash
cd iac/k8s/prometheus-stack && terragrunt apply
terragrunt output -raw grafana_admin_password
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

- Prometheus UI: `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090`
- Istio metrik kontrolü: PromQL `istio_requests_total`
- Grafana'da **PodRestartDetected** alarmı (unified alerting) tanımlıdır.

### Node.js uygulaması

Jenkins'te `03-nodejs-app` job'unu `ACTION=deploy` ile çalıştır: image'ı build/push eder ve chart'ı kurar.

Doğrulama:

```bash
kubectl -n apps get pods -o wide
# 3 pod, her biri farklı application-pool node'unda

INGRESS_IP=$(kubectl -n istio-system get svc istio-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -s "http://${INGRESS_IP}/"
```

### KEDA scale-to-zero

Uygulama chart'ındaki `ScaledObject`:

- Trafik varken: `minReplicaCount=3` … `maxReplicaCount=5`
- 1 saat boyunca istek yoksa (`idleReplicaCount=0`): 0 pod
- Trigger: Prometheus `sum(increase(istio_requests_total{reporter="source",destination_service_name="nodejs-app"}[1h]))`

**Bilinen kısıt:** Pod'lar 0 iken gelen ilk istek(ler) ayağa kalkana kadar 503 alabilir; ingress kaynaklı metrik yine de scale-up'ı tetikler.

### ELK (nice-to-have)

```bash
cd iac/k8s/elk && terragrunt apply

kubectl -n elastic-system get elasticsearch,kibana,beat
kubectl -n elastic-system get secret test-es-es-elastic-user \
  -o go-template='{{.data.elastic | base64decode}}{{"\n"}}'
kubectl -n elastic-system port-forward svc/test-kb-kb-http 5601
# Kibana → Discover → filebeat-* data view
```

### Viewer analiz agent'ı

Jenkins'te `04-viewer-agent` job'unu `ACTION=deploy` ile çalıştır. Pipeline image'ı build/push eder, Grafana'ya port-forward açar (agent Grafana'da viewer service account oluşturur) ve `iac/k8s/agent`'ı apply eder. Grafana şifresi `k8s/prometheus-stack` output'undan otomatik okunur.

```bash
kubectl -n agent port-forward svc/viewer-agent 8080:80
# Tarayıcı: http://localhost:8080
```

| Alan | Yetki |
|------|--------|
| GCP | `roles/viewer` + `roles/aiplatform.user` (Workload Identity) |
| Kubernetes | ClusterRole: get/list/watch (secrets yok) |
| Grafana | Service account **Viewer** token |

## Teardown

```bash
cd iac
terragrunt run --all destroy     # bağımlılıkların tersi sırasıyla siler
```
