# DRM Ledger - Helm Chart

Single-command deployment of the DRM Ledger Hyperledger Fabric blockchain network via Helm.

## Architecture

```
Ordering Service (Org0 - OrdererMSP):
  ├── org0-ca          (Fabric CA, port 443)
  ├── org0-orderer1    (etcdraft, port 6050)
  ├── org0-orderer2    (etcdraft, port 6050)
  └── org0-orderer3    (etcdraft, port 6050)

Org1 (Org1MSP):
  ├── org1-ca          (Fabric CA, port 443)
  ├── org1-peer1       (peer + CouchDB sidecar)
  └── org1-peer2       (peer + CouchDB sidecar)

Org2 (Org2MSP):
  ├── org2-ca          (Fabric CA, port 443)
  ├── org2-peer1       (peer + CouchDB sidecar)
  └── org2-peer2       (peer + CouchDB sidecar)

Chaincode (per peer):
  ├── org1peer1-ccaas-asset-transfer-basic  (CcaaS, port 9999)
  ├── org1peer2-ccaas-asset-transfer-basic  (CcaaS, port 9999)
  ├── org2peer1-ccaas-asset-transfer-basic  (CcaaS, port 9999)
  └── org2peer2-ccaas-asset-transfer-basic  (CcaaS, port 9999)

REST API:
  └── fabric-rest-sample (TypeScript + Redis sidecar, port 3000)
```

**Total pods: ~18** (3 CAs + 3 orderers + 4 peers w/ CouchDB sidecars + 4 chaincode + 1 REST API w/ Redis sidecar + 4 hook Jobs)

## Prerequisites

All prerequisites must be satisfied **before** running `helm install`.

### 1. Kubernetes Cluster (v1.20+)

A running Kubernetes cluster with `kubectl` and `helm` configured.

```bash
# Verify access
kubectl cluster-info
helm version
```

### 2. cert-manager

Required for automatic TLS certificate generation (self-signed root CA chain).

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

# Wait for it to be ready
kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-webhook
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector
```

### 3. NGINX Ingress Controller (with SSL passthrough)

Required for routing to Fabric CA, orderer, and peer endpoints. **SSL passthrough must be enabled**.

```bash
# Add the ingress-nginx repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install with SSL passthrough enabled
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.extraArgs.enable-ssl-passthrough=true

# Wait for it to be ready
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller
```

### 4. Storage Class

A provisioner-backed StorageClass must exist in your cluster. The chart creates 3 PVCs (1 per org, 1Gi each).

```bash
# Check available storage classes
kubectl get sc

# Example output:
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE
# local-path           rancher.io/local-path   Delete          WaitForFirstConsumer
# nfs-client           nfs-provisioner         Delete          Immediate
```

Pass the correct name via `--set global.storageClass=<name>` during install.

### 5. ResourceQuota (if applicable)

If your cluster enforces ResourceQuota on namespaces, ensure the quota can accommodate the deployment. Recommended minimums:

| Resource | Minimum |
|----------|---------|
| `requests.cpu` | 6 |
| `limits.cpu` | 12 |
| `requests.memory` | 12Gi |
| `limits.memory` | 32Gi |
| `pods` | 25 |

### 6. Container Registry Credentials

All images are pulled from the single private repository `ghcr.io/ds2-eu/ds2charts/drm` (one tag per component). Pulling requires the `drm-hook-imagepullsecret` pull secret. The chart creates this secret automatically when you pass `--set imageRegistry.username=` and `--set imageRegistry.password=` (a GitHub username and a PAT with `read:packages`). If the secret is already provided in the namespace (e.g. by the influx/Flux release layer), omit the credentials and the chart will reference the existing secret.

### 7. DNS Resolution

The default domain is `localho.st` which resolves to `127.0.0.1`. If your cluster is remote, either:
- Set up DNS / `/etc/hosts` entries pointing to your ingress controller IP
- Override with `--set global.domain=your-domain.com`

## Quick Start

```bash
# Single command to deploy everything
helm install drm-ledger ./drm-chart \
  --set imageRegistry.username=YOUR_GHCR_USER \
  --set imageRegistry.password='YOUR_GHCR_PAT' \
  --set global.storageClass=YOUR_STORAGE_CLASS
```

This will:
1. Create namespace, PVCs, RBAC, cert-manager issuers, ConfigMaps
2. Deploy 3 CAs, 3 orderers, 4 peers (orderers/peers wait for MSP via init containers)
3. **Hook weight=0**: Enroll all identities inside CA pods
4. **Hook weight=5**: Create channel, join orderers and peers
5. **Hook weight=10**: Install, approve, commit chaincode
6. **Hook weight=15**: Generate REST API config, scale up REST API

### Monitor Progress

```bash
# Watch hook Jobs
kubectl -n drm-ledger get jobs -w

# Follow logs of each hook
kubectl -n drm-ledger logs job/drm-bootstrap-enroll -f
kubectl -n drm-ledger logs job/drm-bootstrap-channel -f
kubectl -n drm-ledger logs job/drm-deploy-chaincode -f
kubectl -n drm-ledger logs job/drm-deploy-rest-api -f

# Check all pods
kubectl -n drm-ledger get pods
```

### Deploy into Existing Namespace

If the namespace already exists:

```bash
helm install drm-ledger ./drm-chart \
  --set global.createNamespace=false \
  --set imageRegistry.username=YOUR_GHCR_USER \
  --set imageRegistry.password='YOUR_GHCR_PAT' \
  --set global.storageClass=YOUR_STORAGE_CLASS
```

## Configuration

All values are configurable via `values.yaml` or `--set` flags.

| Parameter | Default | Description |
|-----------|---------|-------------|
| `global.namespace` | `drm-ledger` | Kubernetes namespace |
| `global.createNamespace` | `true` | Create namespace (set false if it exists) |
| `global.domain` | `localho.st` | Domain for ingress rules |
| `global.storageClass` | `standard` | StorageClass for PVCs |
| `global.storageSize` | `1Gi` | Storage per org PVC |
| `caAdmin.user` | `rcaadmin` | Fabric CA bootstrap admin username |
| `caAdmin.password` | `rcaadminpw` | Fabric CA bootstrap admin password |
| `channel.name` | `mychannel` | Fabric channel name |
| `couchdb.user` | `admin` | CouchDB sidecar username |
| `couchdb.password` | `adminpw` | CouchDB sidecar password |
| `chaincode.name` | `asset-transfer-basic` | Chaincode name |
| `chaincode.version` | `1` | Chaincode version |
| `chaincode.sequence` | `1` | Chaincode sequence |
| `restApi.org1ApiKey` | `97834158-3224-...` | Org1 REST API key |
| `restApi.org2ApiKey` | `BC42E734-062D-...` | Org2 REST API key |
| `restApi.logLevel` | `debug` | REST API log level |
| `imageRegistry.name` | `drm-hook-imagepullsecret` | Name of the ghcr.io pull secret |
| `imageRegistry.server` | `ghcr.io` | Container registry server |
| `imageRegistry.username` | `""` | ghcr.io username (GitHub user) |
| `imageRegistry.password` | `""` | ghcr.io password (GitHub PAT, `read:packages`) |
| `images.*` | see values.yaml | Container image repos/tags |
| `ingress.className` | `nginx` | Ingress class name |

## Test the REST API

Once all pods are running:

```bash
# Get all logs (Org1)
curl http://fabric-rest-sample.localho.st/api/assets \
  -H "X-Api-Key: 97834158-3224-4CE7-95F9-A148C886653E"

# Create a log
curl -X POST http://fabric-rest-sample.localho.st/api/assets \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: 97834158-3224-4CE7-95F9-A148C886653E" \
  -d '{"id":"log-1","type":"LogCreated","logType":"policy","payload":{"key":"value"}}'

# Check job status (replace <jobId>)
curl http://fabric-rest-sample.localho.st/api/jobs/<jobId> \
  -H "X-Api-Key: 97834158-3224-4CE7-95F9-A148C886653E"

# Read a log
curl http://fabric-rest-sample.localho.st/api/assets/log-1 \
  -H "X-Api-Key: 97834158-3224-4CE7-95F9-A148C886653E"

# Update a log
curl -X PUT http://fabric-rest-sample.localho.st/api/assets/log-1 \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: 97834158-3224-4CE7-95F9-A148C886653E" \
  -d '{"id":"log-1","type":"LogUpdated","logType":"policy","payload":{"key":"updated"}}'

# Delete a log
curl -X DELETE http://fabric-rest-sample.localho.st/api/assets/log-1 \
  -H "X-Api-Key: 97834158-3224-4CE7-95F9-A148C886653E"

# Use Org2 API key
curl http://fabric-rest-sample.localho.st/api/assets \
  -H "X-Api-Key: BC42E734-062D-4AEE-A591-5973CB763430"
```

Write operations (create, update, delete) are **asynchronous** — they return a `jobId`. Poll `/api/jobs/<jobId>` for completion.

## Uninstall

```bash
helm uninstall drm-ledger
kubectl delete namespace drm-ledger
```

## Image Versions

All images live in the single repository `ghcr.io/ds2-eu/ds2charts/drm`, distinguished by tag.

| Component | Image | Tag |
|-----------|-------|-----|
| Fabric CA | `ghcr.io/ds2-eu/ds2charts/drm` | fabric-ca-1.5 |
| Fabric Orderer | `ghcr.io/ds2-eu/ds2charts/drm` | fabric-orderer-2.5 |
| Fabric Peer | `ghcr.io/ds2-eu/ds2charts/drm` | fabric-peer-2.5 |
| Fabric Tools | `ghcr.io/ds2-eu/ds2charts/drm` | fabric-tools-2.5 |
| CouchDB | `ghcr.io/ds2-eu/ds2charts/drm` | couchdb-3.3.3 |
| Redis | `ghcr.io/ds2-eu/ds2charts/drm` | redis-6.2.5 |
| busybox (init) | `ghcr.io/ds2-eu/ds2charts/drm` | busybox-1.36 |
| REST API | `ghcr.io/ds2-eu/ds2charts/drm` | drm-rest-api |
| Chaincode | `ghcr.io/ds2-eu/ds2charts/drm` | chaincode |
| DRM UI Backend | `ghcr.io/ds2-eu/ds2charts/drm` | drm-ui-be |
| DRM UI Frontend | `ghcr.io/ds2-eu/ds2charts/drm` | drm-ui-fe |
| kubectl (hooks) | `ghcr.io/ds2-eu/ds2charts/drm` | kubectl-latest |

## Ingress Endpoints

| Endpoint | Service | Protocol |
|----------|---------|----------|
| `org0-ca.localho.st` | Org0 CA | HTTPS (ssl-passthrough) |
| `org1-ca.localho.st` | Org1 CA | HTTPS (ssl-passthrough) |
| `org2-ca.localho.st` | Org2 CA | HTTPS (ssl-passthrough) |
| `org0-orderer{1,2,3}.localho.st` | Orderers | gRPC+TLS (ssl-passthrough) |
| `org0-orderer{1,2,3}-admin.localho.st` | Orderer Admin | gRPC+TLS (ssl-passthrough) |
| `org{1,2}-peer{1,2}.localho.st` | Peer gRPC | gRPC+TLS (ssl-passthrough) |
| `org{1,2}-peer-gateway-svc.localho.st` | Peer Gateway | gRPC+TLS (ssl-passthrough) |
| `fabric-rest-sample.localho.st` | REST API | HTTP |

## Notes

- **No local Fabric CLI required** — all operations run inside cluster pods via `kubectl exec`
- **CouchDB credentials** default to `admin/adminpw` — change for production
- **CA admin credentials** default to `rcaadmin/rcaadminpw` — change for production
- **REST API keys** are configurable in values.yaml — change for production
- The chaincode uses a **Log** data model (not standard Asset): fields are `id`, `type`, `logType`, `payload`
- All TLS certificates are managed by **cert-manager** with a self-signed root CA chain
- Orderers/peers use **init containers** that wait for MSP files before starting
- Chaincode and REST API deployments start with **replicas=0** and are scaled up by hook Jobs
