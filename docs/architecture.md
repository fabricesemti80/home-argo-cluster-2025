# Cluster Architecture

This document provides a visual overview of the cluster architecture, explaining how the different components interact and work together.

## Overview

This cluster is a **GitOps-managed Kubernetes homelab** built on Talos Linux, with all infrastructure defined as code in this repository. Changes pushed to Git automatically sync to the cluster via Argo CD.

```mermaid
flowchart TB
    subgraph Git["Git Repository (This Repo)"]
        direction TB
        Code[("YAML<br/>Configurations")]
        Secrets[("SOPS<br/>Secrets")]
    end

    subgraph Cluster["Kubernetes Cluster"]
        subgraph ControlPlane["Control Plane"]
            API[Kube API]
            etcd[etcd]
            Scheduler
            ControllerMgr
        end
        
        subgraph Workers["Worker Nodes"]
            W1[k8s-wrkr-01]
            W2[k8s-wrkr-02]
            W3[k8s-wrkr-03]
        end
        
        subgraph System["System Pods"]
            CNI[Cilium]
            DNS[CoreDNS]
            Ingress[Envoy Gateway]
        end
        
        subgraph Apps["User Applications"]
            Argo[Argo CD]
            UserApp[Your Apps]
        end
    end
    
    subgraph External["External Network"]
        Users[("Users")]
        Cloudflare[("Cloudflare")]
        Internet[("Internet")]
    end
    
    Git -->|Push| Argo
    Argo -->|Sync| Cluster
    Users -->|HTTPS| Cloudflare
    Cloudflare -->|Tunnel| Ingress
    Ingress -->|Route| UserApp
```

## High-Level Data Flow

```mermaid
sequenceDiagram
    participant U as User
    participant CF as Cloudflare
    participant CT as Cloudflared
    participant EG as Envoy Gateway
    participant SVC as Service
    participant POD as Pod

    U->>CF: Request https://argo.krapulax.dev
    CF->>CT: Forward via Tunnel
    CT->>EG: HTTPS -> Envoy External LB
    EG->>SVC: Route to argocd-server:80
    SVC->>POD: Forward to Pod Port 8080
    POD-->>SVC: Response
    SVC-->>EG: Response
    EG-->>CT: Response
    CT-->>CF: Response
    CF-->>U: Response
```

## Network Architecture

### IP Allocation

| IP | Component |
|---|---|
| `10.0.40.90-92` | Control Plane Nodes |
| `10.0.40.93-95` | Worker Nodes |
| `10.0.40.101` | Kubernetes API VIP |
| `10.0.40.102` | Internal Gateway (Envoy) |
| `10.0.40.103` | External Gateway (Envoy) |
| `10.0.40.153` | DNS Gateway (k8s-gateway) |

### CIDRs

| Network | CIDR |
|---------|------|
| Pods | `10.42.0.0/16` |
| Services | `10.43.0.0/16` |
| Nodes | `10.0.40.0/24` |

```mermaid
flowchart LR
    subgraph NodeNetwork["10.0.40.0/24"]
        VIP[VIP<br/>10.0.40.101]
        IG[Internal<br/>Gateway<br/>10.0.40.102]
        EG[External<br/>Gateway<br/>10.0.40.103]
        DNS[DNS<br/>Gateway<br/>10.0.40.153]
        
        subgraph Ctrl["Controllers"]
            C1[10.0.40.90]
            C2[10.0.40.91]
            C3[10.0.40.92]
        end
        
        subgraph Wrkr["Workers"]
            W1[10.0.40.93]
            W2[10.0.40.94]
            W3[10.0.40.95]
        end
    end
    
    subgraph Pods["10.42.0.0/16"]
        P1[Pod 1]
        P2[Pod 2]
        P3[Pod 3]
    end
    
    subgraph Services["10.43.0.0/16"]
        S1[Service 1]
        S2[Service 2]
    end
    
    EG -->|HTTPS/443| Internet
    IG -->|HTTP/443| HomeNet
    DNS -->|DNS/53| HomeNet
    
    C1 & C2 & C3 --> Pods
    W1 & W2 & W3 --> Pods
    Pods --> Services
```

## Component Architecture

### GitOps Pipeline

```mermaid
flowchart TB
    subgraph GitOps["GitOps Flow"]
        Git[(Git Repo)]
        Commit[("Commit<br/>Push")]
        Argo[Argo CD]
        Reconcile[Reconcile]
        Cluster[K8s Cluster]
    end
    
    subgraph Sources["Sources"]
        Helm[Helm Charts]
        Kustomize[Kustomize]
        SOPS[SOPS Secrets]
    end
    
    Git -->|1. Push| Commit
    Commit -->|2. Detect| Argo
    Argo -->|3. Read| Sources
    Argo -->|4. Apply| Reconcile
    Reconcile -->|5. Sync| Cluster
```

### Ingress Architecture

```mermaid
flowchart TB
    subgraph External["External Access"]
        CF[Cloudflare]
        Tunnel[Cloudflared<br/>Tunnel]
    end
    
    subgraph Gateway["Envoy Gateway"]
        ExtLB["External LB<br/>10.0.40.103"]
        IntLB["Internal LB<br/>10.0.40.102"]
        
        subgraph Routes["HTTPRoutes"]
            PubRoute[Public Routes]
            PrivRoute[Private Routes]
        end
        
        ExtLB --> Routes
        IntLB --> Routes
    end
    
    subgraph Services["Cluster Services"]
        ArgoSVC[Argo CD<br/>Server]
        EchoSVC[Echo<br/>App]
        CustomSVC[Your App]
    end
    
    Tunnel -->|HTTPS| ExtLB
    Routes -->|Route| ArgoSVC
    Routes -->|Route| EchoSVC
    Routes -->|Route| CustomSVC
```

### DNS Resolution

```mermaid
flowchart LR
    subgraph ExternalDNS["External DNS"]
        ExtDNS[Cloudflare<br/>DNS]
    end
    
    subgraph ClusterDNS["Cluster DNS"]
        CoreDNS[CoreDNS]
        K8sGW["k8s-gateway<br/>10.0.40.153"]
    end
    
    subgraph Clients["Clients"]
        Home[Home Network<br/>Using k8s-gateway]
        Pub[Public Internet<br/>Using Cloudflare]
    end
    
    Pub -->|Query| ExtDNS
    Home -->|Query| K8sGW
    K8sGW -->|Forward| CoreDNS
    ExtDNS -->|Serve| Pub
    CoreDNS -->|Serve| Home
```

## Repository Structure

```
.
├── bootstrap/              # Initial cluster bootstrap
│   └── helmfile.d/        # Helmfile for bootstrap apps
├── kubernetes/            # Main GitOps manifests
│   ├── apps/              # Application Helm values
│   │   └── <namespace>/  # Organized by namespace
│   │       └── <app>/    # Individual app configs
│   │           ├── values.yaml
│   │           └── values.sops.yaml
│   ├── argo/              # Argo CD Applications
│   │   ├── apps/         # Application manifests
│   │   └── repositories/ # Repo definitions
│   └── components/        # Shared Kustomize components
├── talos/                 # Talos Linux configs
├── terraform/             # VM provisioning
├── templates/             # makejinja templates
├── cluster.yaml           # Cluster configuration
└── nodes.yaml             # Node inventory
```

```mermaid
flowchart TB
    subgraph Template["Templates"]
        T1[cluster.yaml]
        T2[nodes.yaml]
    end
    
    subgraph Render["makejinja Render"]
        Config[("Config Files")]
    end
    
    subgraph GitOps["GitOps"]
        Apps[("App Values")]
        Argo[("Argo Apps")]
        Talos[("Talos Config")]
    end
    
    T1 & T2 -->|render| Config
    Config -->|deploy| Apps
    Config -->|deploy| Argo
    Config -->|deploy| Talos
```

## Security Model

### Secrets Management

```mermaid
flowchart LR
    subgraph Editor["Editor"]
        Dev[Developer]
    end
    
    subgraph Encrypt["Encrypt with SOPS"]
        Age[age key]
        Plain[Plaintext YAML]
        Enc[Encrypted YAML]
    end
    
    subgraph Deploy["Deploy"]
        Argo[Argo CD]
        Cluster[K8s Cluster]
    end
    
    subgraph Runtime["Runtime"]
        Decrypt[Decrypt]
        Pod[Pod with<br/>Secrets]
    end
    
    Dev -->|Edit| Plain
    Age -->|Encrypt| Plain
    Plain -->|→| Enc
    Enc -->|Git Push| Argo
    Argo -->|Apply| Cluster
    Cluster -->|Decrypt| Decrypt
    Decrypt -->|Mount| Pod
```

### Network Policies

- **Cilium** handles pod-to-pod communication and network policies
- **DSR (Direct Server Return)** mode for efficient load balancing
- **kube-proxy** is replaced by Cilium

## Access Paths

### External Access (Internet)

```mermaid
flowchart LR
    User[("User<br/>Browser")]
    CF[("Cloudflare")]
    Tunnel[Cloudflared]
    EG[Envoy<br/>External]
    SVC[Service]
    Pod[Pod]
    
    User -->|HTTPS| CF
    CF -->|Tunnel| Tunnel
    Tunnel -->|HTTPS| EG
    EG -->|HTTP| SVC
    SVC -->|Connect| Pod
```

### Internal Access (Home Network)

```mermaid
flowchart LR
    Laptop[("Laptop")]
    DNS[("k8s-gateway<br/>10.0.40.153")]
    EGInt[Envoy<br/>Internal]
    SVC[Service]
    Pod[Pod]
    
    Laptop -->|DNS Query| DNS
    DNS -->|A Record| EGInt
    Laptop -->|HTTPS| EGInt
    EGInt -->|HTTP| SVC
    SVC -->|Connect| Pod
```

### Admin Access

```mermaid
flowchart LR
    Admin[("Admin<br/>Local Machine")]
    VIP[VIP<br/>10.0.40.101]
    API[Kube API]
    Talos[Talos API]
    
    Admin -->|kubectl| VIP
    Admin -->|talosctl| Talos
    VIP -->|Auth| API
    Talos -->|Auth| API
```

## Application Deployment Flow

```mermaid
flowchart TB
    Start[("Add New<br/>Application")] --> Step1
    
    subgraph Step1["1. Create App Files"]
        D1[mkdir apps/ns/app]
        V1[values.yaml]
        S1[values.sops.yaml]
    end
    
    Step1 --> Step2
    
    subgraph Step2["2. Create Argo App"]
        A1[argo/apps/ns/app.yaml]
    end
    
    Step2 --> Step3
    
    subgraph Step3["3. Expose (Optional)"]
        R1[HTTPRoute<br/>envoy-external]
        R2[HTTPRoute<br/>envoy-internal]
    end
    
    Step3 --> Step4
    
    subgraph Step4["4. Commit & Push"]
        Git[("git add<br/>git commit<br/>git push")]
    end
    
    Step4 --> End[("Auto Deploy<br/>by Argo CD")]
```

## Key Components

| Component | Purpose | Namespace |
|-----------|---------|-----------|
| **Talos Linux** | Immutable OS | - |
| **Cilium** | CNI, Network Policies | kube-system |
| **CoreDNS** | Cluster DNS | kube-system |
| **k8s-gateway** | Split DNS | network |
| **Envoy Gateway** | Ingress | network |
| **Argo CD** | GitOps Controller | argo-system |
| **cert-manager** | TLS Certificates | cert-manager |
| **Spegel** | P2P Registry Mirror | kube-system |
| **Reloader** | Config Reload | kube-system |
| **Cloudflared** | Cloudflare Tunnel | network |

## Troubleshooting Paths

```mermaid
flowchart TB
    Issue[("Issue<br/>Reported")] --> Check
    
    subgraph Check["Diagnostic Steps"]
        C1["kubectl get pods -A"]
        C2["kubectl get events --sort-by=.timestamp"]
        C3["argocd app list"]
        C4["cilium status"]
    end
    
    Check --> Analyze
    
    subgraph Analyze["Common Causes"]
        A1[Pod Crash]
        A2[Network Policy]
        A3[Sync Error]
        A4[Config Issue]
    end
    
    Analyze --> Fix
    
    subgraph Fix["Resolution"]
        F1["kubectl logs<br/>kubectl describe"]
        F2["argocd app sync"]
        F3["Check YAML<br/>Check Secrets"]
    end
```
