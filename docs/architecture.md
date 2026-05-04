# Architecture

Install a **Mermaid preview plugin** in your editor to render the diagrams in this Markdown file.

Helix runs a Flask user portal and a MySQL database on GKE. Terraform creates the Google Cloud foundation, and Helm deploys the workloads.

## High Level

```mermaid
flowchart TB
    user[End User] --> host[sslip.io Hostname]
    host --> lb[External HTTP Load Balancer]
    lb --> ingress[GKE Ingress]

    subgraph project[Google Cloud Sandbox Project]
        subgraph vpc[VPC]
            ingress --> portal[User Portal UI + API]
            portal --> mysql[(MySQL StatefulSet)]
            nat[Cloud NAT] --> internet[Internet Egress]
        end

        portal --> logging[Cloud Logging]
        portal --> trace[Cloud Trace]
        logging --> bq[(BigQuery Log Datasets)]
        bq --> grafana[Grafana Cloud]
        monitoring[Cloud Monitoring] --> grafana
    end
```

## Terraform Resources

```mermaid
flowchart LR
    tf[Terraform] --> state[GCS State Bucket]
    tf --> apis[Project APIs]
    tf --> iam[IAM and Service Accounts]
    tf --> net[VPC and Subnets]
    net --> psa[Private Service Access]
    net --> nat[Cloud NAT]
    net --> fw[Firewall Rules]
    tf --> ar[Artifact Registry]
    tf --> gke[Primary and Secondary GKE]
    tf --> secrets[Secret Manager]
    tf --> ingress_ip[Global Ingress IP]
    tf --> sinks[Log Sinks]
    sinks --> bq[BigQuery]
```

## Kubernetes Workloads

```mermaid
flowchart TB
    subgraph gke[GKE Cluster]
        subgraph ns[Namespace: helix]
            ingress[Ingress]
            portal_svc[Service: user-portal]
            portal[Deployment: user-portal]
            mysql_svc[Service: mysql]
            mysql[StatefulSet: mysql]
            ksa[KSA: helix-user-portal]
        end
    end

    ingress --> portal_svc
    portal_svc --> portal
    portal --> mysql_svc
    mysql_svc --> mysql
    ksa --> portal
    ksa -.Workload Identity.-> gsa[Compute Default Service Account]
```

## Observability Flow

```mermaid
flowchart LR
    portal[User Portal] --> json[JSON stdout logs]
    json --> logging[Cloud Logging]
    logging --> sink[Log Sink]
    sink --> bq[(BigQuery)]
    portal --> otel[OpenTelemetry]
    otel --> trace[Cloud Trace]
    gke[GKE Metrics] --> monitoring[Cloud Monitoring]
    bq --> grafana[Grafana Dashboards]
    monitoring --> grafana
```

## Delivery Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Script as Setup Scripts
    participant TF as Terraform
    participant AR as Artifact Registry
    participant Helm as Helm
    participant GKE as GKE

    Dev->>Script: Run setup_new_sandbox.sh
    Script->>TF: Bootstrap and apply infrastructure
    Script->>AR: Build and push images
    Script->>Helm: Deploy charts
    Helm->>GKE: Roll out MySQL and user-portal
    Script->>GKE: Smoke test app and trace setup
```
