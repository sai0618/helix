# Helix Helm Charts

Helm charts for deploying the Helix user registration application to GKE.

## Charts

- `mysql`: MySQL StatefulSet with persistent storage and initialization SQL.
- `user-portal`: merged Flask/Jinja UI and REST API service.

## Build And Push Images

Build and push both images. The script reads the existing `vN` tags from Artifact Registry and chooses the next version automatically:

```bash
scripts/build_new_sandbox_images.sh --mode docker
```

Deploy both charts to the sandbox clusters:

```bash
PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/deploy_new_sandbox_apps.sh
```

## External Browser Access

Reserve the ingress IP with Terraform:

```bash
cd iac/terraform/environments/sandbox
terraform apply -target=module.ingress_foundation -var=enable_ingress_foundation=true
```

Expose the portal with GKE external Ingress:

```bash
PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/expose_user_portal_external.sh \
  --project-id PROJECT_ID
```

Check the URL at any time:

```bash
PATH=/opt/homebrew/share/google-cloud-sdk/bin:/opt/homebrew/bin:$PATH \
USE_GKE_GCLOUD_AUTH_PLUGIN=True \
scripts/get_user_portal_url.sh \
  --project-id PROJECT_ID
```

## Credentials

The app login secret is stored in Secret Manager as `helix-sandbox-app-login-credentials`.
The default username is `admin`; read the password from Secret Manager or `.helix-sandbox.env`.

Read it with:

```bash
gcloud secrets versions access latest \
  --secret helix-sandbox-app-login-credentials \
  --project PROJECT_ID
```

## Manual Install

Install the database first:

```bash
helm upgrade --install helix-mysql ./helm-charts/mysql \
  --namespace helix --create-namespace
```

Install the web/API app:

```bash
helm upgrade --install helix-user-portal ./helm-charts/user-portal \
  --namespace helix \
  --set image.repository=us-central1-docker.pkg.dev/PROJECT_ID/helix-sandbox-docker/user-portal \
  --set image.tag=latest \
  --set config.mysqlHost=helix-mysql \
  --set config.existingSecret=helix-mysql \
  --set config.mysqlPasswordKey=mysql-password
```

To read application login and MySQL credentials from GCP Secret Manager, enable the GKE Secret Manager CSI driver on the cluster and install the chart with Secret Manager mounting enabled:

```bash
helm upgrade --install helix-user-portal ./helm-charts/user-portal \
  --namespace helix \
  --set image.repository=us-central1-docker.pkg.dev/PROJECT_ID/helix-sandbox-docker/user-portal \
  --set image.tag=latest \
  --set secretManager.enabled=true \
  --set secretManager.projectId=PROJECT_ID \
  --set secretManager.appLoginSecretName=helix-sandbox-app-login-credentials \
  --set secretManager.mysqlSecretName=helix-sandbox-mysql-credentials
```

The mounted Secret Manager payloads are JSON files:

```json
{"username":"admin","password":"ChangeMe123!"}
```

```json
{"username":"helix_app","password":"helix-dev-password","database":"helix_users","host":"helix-mysql","port":"3306"}
```

## Ingress And Mesh

External GKE Ingress using the global static IP from Terraform:

```bash
helm upgrade --install helix-user-portal ./helm-charts/user-portal \
  --namespace helix \
  --set externalIngress.enabled=true \
  --set externalIngress.staticIpName=helix-sandbox-external-https-ip \
  --set externalIngress.host=user-portal.example.com
```

Internal GKE Ingress using the regional internal IP from Terraform:

```bash
helm upgrade --install helix-user-portal ./helm-charts/user-portal \
  --namespace helix \
  --set internalIngress.enabled=true \
  --set internalIngress.staticIpName=helix-sandbox-internal-ingress-ip \
  --set internalIngress.host=user-portal.internal.example.com
```

Multi Cluster Ingress and Multi Cluster Service for a single global IP across fleet clusters:

```bash
helm upgrade --install helix-user-portal ./helm-charts/user-portal \
  --namespace helix \
  --set multiClusterIngress.enabled=true \
  --set multiClusterIngress.staticIpAddress=EXTERNAL_HTTPS_IP_ADDRESS \
  --set multiClusterIngress.host=user-portal.example.com
```

Deploy the `MultiClusterIngress` and `MultiClusterService` resources only to the config cluster selected by Terraform, while deploying the normal workload chart to each serving cluster in the same namespace.

Cloud Service Mesh policies:

```bash
helm upgrade --install helix-user-portal ./helm-charts/user-portal \
  --namespace helix \
  --set serviceMesh.enabled=true \
  --set serviceMesh.mtlsMode=STRICT \
  --set serviceMesh.virtualService.stableWeight=100 \
  --set serviceMesh.virtualService.canaryWeight=0
```

For sidecar injection, label the namespace in each cluster after managed Cloud Service Mesh is ready:

```bash
kubectl label namespace helix istio-injection=enabled --overwrite
```

## Verify

```bash
kubectl get pods -n helix
kubectl get svc -n helix
```

The app exposes port `8080` inside the cluster. Use `externalIngress`, `internalIngress`, or `multiClusterIngress` depending on the traffic path you are testing.

## Lint

```bash
helm lint ./helm-charts/mysql
helm lint ./helm-charts/user-portal
```
