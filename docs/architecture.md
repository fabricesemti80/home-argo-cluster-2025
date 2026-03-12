# Cluster Architecture

This document provides a visual overview of the cluster architecture, explaining how the different components interact and work together.

## Overview

This cluster is a **GitOps-managed Kubernetes homelab** built on Talos Linux, with all infrastructure defined as code in this repository. Changes pushed to Git automatically sync to the cluster via Argo CD.

```mermaid
%%{init: {'theme': 'dark', 'themeVariables': { 'primaryColor': '#1a1a2e', 'primaryTextColor': '#eee', 'primaryBorderColor': '#0f3460', 'lineColor': '#e94560', 'secondaryColor': '#16213e', 'tertiaryColor': '#0f3460'}}}%%
flowchart TB
    %% Styling
    classDef repo fill:#2d6a4f,stroke:#40916c,stroke-width:2px,color:#fff
    classDef cluster fill:#1a1a2e,stroke:#e94560,stroke-width:2px,color:#fff
    classDef controlplane fill:#7b2cbf,stroke:#9d4edd,stroke-width:2px,color:#fff
    classDef worker fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff
    classDef system fill:#9d0208,stroke:#d00000,stroke-width:2px,color:#fff
    classDef app fill:#1a1a2e,stroke:#00b4d8,stroke-width:2px,color:#fff
    classDef external fill:#e85d04,stroke:#f48c06,stroke-width:2px,color:#fff
    classDef user fill:#6c757d,stroke:#adb5bd,stroke-width:2px,color:#fff
    
    subgraph Git["🗂️ Git Repository"]
        direction TB
        Code["📄 YAML Configs"]
        Secrets["🔐 SOPS Secrets"]
    end
    class Git,Code,Secrets repo
    
    subgraph Cluster["☸️ Kubernetes Cluster"]
        direction TB
        
        subgraph ControlPlane["🎛️ Control Plane"]
            direction LR
            API["API Server"]
            etcd["etcd"]
            Scheduler["Scheduler"]
            ControllerMgr["Controller\nManager"]
        end
        class ControlPlane,API,etcd,Scheduler,ControllerMgr controlplane
        
        subgraph Workers["⚙️ Worker Nodes"]
            direction LR
            W1["k8s-wrkr-01"]
            W2["k8s-wrkr-02"]
            W3["k8s-wrkr-03"]
        end
        class Workers,W1,W2,W3 worker
        
        subgraph System["🔧 System Pods"]
            direction LR
            CNI["🕸️ Cilium"]
            DNS["📡 CoreDNS"]
            Ingress["🚪 Envoy\nGateway"]
        end
        class System,CNI,DNS,Ingress system
        
        subgraph Apps["📦 Applications"]
            direction LR
            Argo["⚡ Argo CD"]
            UserApp["📱 Your Apps"]
        end
        class Apps,Argo,UserApp app
    end
    class Cluster cluster
    
    subgraph External["🌍 External Network"]
        Users["👤 Users"]
        Cloudflare["☁️ Cloudflare"]
    end
    class External,Users,Cloudflare external
    class Users user
    
    Git --"Push"--> Argo
    Argo --"Sync"--> Cluster
    Users --"HTTPS"--> Cloudflare
    Cloudflare --"Tunnel"--> Ingress
    Ingress --"Route"--> UserApp
```

## High-Level Data Flow

```mermaid
%%{init: {'theme': 'dark'}}%%
sequenceDiagram
    participant U as 👤 User
    participant CF as ☁️ Cloudflare
    participant CT as 🌐 Cloudflared
    participant EG as 🚪 Envoy Gateway
    participant SVC as 🔗 Service
    participant POD as 📦 Pod

    U->>CF: Request<br/>https://argo.krapulax.dev
    CF->>CT: Forward via Tunnel
    CT->>EG: HTTPS Request
    Note over EG: Routes to<br/>argocd-server:80
    EG->>SVC: Forward to Service
    SVC->>POD: Connect to Pod<br/>Port 8080
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
%%{init: {'theme': 'dark', 'themeVariables': { 'primaryColor': '#1a1a2e'}}}%%
flowchart LR
    %% Styles
    classDef node fill:#023e8a,stroke:#0077b6,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef vip fill:#7b2cbf,stroke:#9d4edd,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef gateway fill:#9d0208,stroke:#d00000,stroke-width:3px,color:#fff,rx:10,ry:10
    classDef network fill:#1a1a2e,stroke:#00b4d8,stroke-width:2px,color:#fff
    classDef cidr fill:#2d6a4f,stroke:#40916c,stroke-width:2px,color:#fff,rx:5
    
    subgraph NodeNetwork["🏠 Node Network 10.0.40.0/24"]
        direction TB
        VIP["🎯 VIP<br/>10.0.40.101<br/>Kube API"]:::vip
        IG["🏠 Internal GW<br/>10.0.40.102"]:::gateway
        EG["🌍 External GW<br/>10.0.40.103"]:::gateway
        DNS["📡 DNS GW<br/>10.0.40.153"]:::gateway
        
        subgraph Ctrl["🎛️ Controllers"]
            direction LR
            C1["10.0.40.90"]:::node
            C2["10.0.40.91"]:::node
            C3["10.0.40.92"]:::node
        end
        
        subgraph Wrkr["⚙️ Workers"]
            direction LR
            W1["10.0.40.93"]:::node
            W2["10.0.40.94"]:::node
            W3["10.0.40.95"]:::node
        end
    end
    
    subgraph Pods["📦 Pods 10.42.0.0/16":::cidr]
        direction TB
        P1["Pod"]:::network
        P2["Pod"]:::network
        P3["Pod"]:::network
    end
    
    subgraph Services["🔗 Services 10.43.0.0/16":::cidr]
        direction TB
        S1["Service"]:::network
        S2["Service"]:::network
    end
    
    EG -.->|"HTTPS/443"| Internet["🌐 Internet"]
    IG -.->|"HTTPS"| Home["🏠 Home"]
    DNS -.->|"DNS/53"| Home
    
    C1 & C2 & C3 --> P1 & P2 & P3
    W1 & W2 & W3 --> P1 & P2 & P3
    P1 & P2 & P3 --> S1 & S2
```

## Component Architecture

### GitOps Pipeline

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart TB
    %% Styles
    classDef git fill:#2d6a4f,stroke:#40916c,stroke-width:3px,color:#fff,rx:10
    classDef argocd fill:#7b2cbf,stroke:#9d4edd,stroke-width:3px,color:#fff,rx:10
    classDef source fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff,rx:5
    classDef process fill:#9d0208,stroke:#d00000,stroke-width:2px,color:#fff,rx:5
    
    subgraph Deploy["🚀 Deployment Pipeline"]
        Git["📤 Git Push"]:::git
        Argo["⚡ Argo CD<br/>Detects Change"]:::argocd
        Sync["🔄 Sync &<br/>Apply"]:::process
        Cluster["☸️ Cluster"]:::git
    end
    
    subgraph Sources["📋 Sources"]
        direction LR
        Helm["🎯 Helm<br/>Charts"]:::source
        Kustomize["🔧 Kustomize"]:::source
        SOPS["🔐 SOPS<br/>Secrets"]:::source
    end
    
    Git -->|"1. Push"| Argo
    Argo -->|"2. Read"| Sources
    Argo -->|"3. Apply"| Sync
    Sync -->|"4. Sync"| Cluster
```

### Ingress Architecture

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart TB
    %% Styles
    classDef cloud fill:#e85d04,stroke:#f48c06,stroke-width:3px,color:#fff,rx:10
    classDef tunnel fill:#f48c06,stroke:#fca311,stroke-width:2px,color:#fff,rx:5
    classDef gateway fill:#9d0208,stroke:#d00000,stroke-width:3px,color:#fff,rx:10
    classDef route fill:#7b2cbf,stroke:#9d4edd,stroke-width:2px,color:#fff,rx:5
    classDef service fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff,rx:5
    
    subgraph External["☁️ External Access"]
        CF["☁️ Cloudflare"]:::cloud
        Tunnel["🌐 Cloudflared<br/>Tunnel"]:::tunnel
    end
    
    subgraph Gateway["🚪 Envoy Gateway"]
        ExtLB["🌍 External LB<br/>10.0.40.103"]:::gateway
        IntLB["🏠 Internal LB<br/>10.0.40.102"]:::gateway
        
        subgraph Routes["🛤️ HTTPRoutes"]
            direction LR
            Pub["🔓 Public"]:::route
            Priv["🔒 Private"]:::route
        end
        
        ExtLB --> Routes
        IntLB --> Routes
    end
    
    subgraph ClusterServices["📦 Cluster Services"]
        direction LR
        ArgoSVC["⚡ Argo CD"]:::service
        EchoSVC["📢 Echo App"]:::service
        CustomSVC["📱 Your App"]:::service
    end
    
    CF -->|"HTTPS"| Tunnel
    Tunnel -->|"HTTPS"| ExtLB
    Routes -->|"Route"| ArgoSVC
    Routes -->|"Route"| EchoSVC
    Routes -->|"Route"| CustomSVC
```

### DNS Resolution

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart LR
    %% Styles
    classDef dns fill:#7b2cbf,stroke:#9d4edd,stroke-width:3px,color:#fff,rx:10
    classDef client fill:#6c757d,stroke:#adb5bd,stroke-width:2px,color:#fff,rx:5
    classDef cloud fill:#e85d04,stroke:#f48c06,stroke-width:2px,color:#fff,rx:5
    
    subgraph ExternalDNS["☁️ External DNS"]
        ExtDNS["☁️ Cloudflare<br/>DNS"]:::cloud
    end
    
    subgraph ClusterDNS["🔧 Cluster DNS"]
        CoreDNS["📡 CoreDNS"]:::dns
        K8sGW["🕸️ k8s-gateway<br/>10.0.40.153"]:::dns
    end
    
    subgraph Clients["👤 Clients"]
        Home["🏠 Home Network"]:::client
        Pub["🌍 Public Internet"]:::client
    end
    
    Pub --"DNS Query"--> ExtDNS
    Home --"DNS Query"--> K8sGW
    K8sGW --"Forward"--> CoreDNS
    ExtDNS --"A Record"--> Pub
    CoreDNS --"A Record"--> Home
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
%%{init: {'theme': 'dark'}}%%
flowchart TB
    %% Styles
    classDef input fill:#2d6a4f,stroke:#40916c,stroke-width:3px,color:#fff,rx:10
    classDef render fill:#7b2cbf,stroke:#9d4edd,stroke-width:2px,color:#fff,rx:5
    classDef output fill:#023e8a,stroke:#0077b6,stroke-width:3px,color:#fff,rx:10
    
    subgraph Input["📥 Input Files"]
        T1["📝 cluster.yaml"]
        T2["📝 nodes.yaml"]
    end
    class Input,T1,T2 input
    
    subgraph Render["⚙️ makejinja Render"]
        Config["⚡ Rendered<br/>Config Files"]:::render
    end
    
    subgraph GitOps["📤 GitOps Output"]
        Apps["📦 App Values"]:::output
        Argo["⚡ Argo Apps"]:::output
        Talos["🖥️ Talos Config"]:::output
    end
    
    T1 & T2 -->|"render"| Config
    Config -->|"deploy"| Apps
    Config -->|"deploy"| Argo
    Config -->|"deploy"| Talos
```

## Security Model

### Secrets Management

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart LR
    %% Styles
    classDef dev fill:#2d6a4f,stroke:#40916c,stroke-width:3px,color:#fff,rx:10
    classDef encrypt fill:#7b2cbf,stroke:#9d4edd,stroke-width:2px,color:#fff,rx:5
    classDef deploy fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff,rx:5
    classDef runtime fill:#9d0208,stroke:#d00000,stroke-width:2px,color:#fff,rx:5
    
    subgraph Editor["👨‍💻 Editor"]
        Dev["Developer"]:::dev
    end
    
    subgraph Encrypt["🔐 Encrypt with SOPS"]
        Age["🔑 age Key"]:::encrypt
        Plain["📄 Plaintext<br/>YAML"]:::encrypt
        Enc["🔒 Encrypted<br/>YAML"]:::encrypt
    end
    
    subgraph Deploy["🚀 Deploy"]
        Argo["⚡ Argo CD"]:::deploy
        Cluster["☸️ Cluster"]:::deploy
    end
    
    subgraph Runtime["⏱️ Runtime"]
        Decrypt["🔓 Decrypt"]:::runtime
        Pod["📦 Pod with<br/>Secrets"]:::runtime
    end
    
    Dev --"Edit"--> Plain
    Age --"Encrypt"--> Plain
    Plain --"→"--> Enc
    Enc --"Git Push"--> Argo
    Argo --"Apply"--> Cluster
    Cluster --"Decrypt"--> Decrypt
    Decrypt --"Mount"--> Pod
```

## Access Paths

### External Access (Internet)

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart LR
    %% Styles
    classDef user fill:#6c757d,stroke:#adb5bd,stroke-width:2px,color:#fff,rx:10
    classDef cloud fill:#e85d04,stroke:#f48c06,stroke-width:3px,color:#fff,rx:10
    classDef tunnel fill:#f48c06,stroke:#fca311,stroke-width:2px,color:#fff,rx:5
    classDef gateway fill:#9d0208,stroke:#d00000,stroke-width:3px,color:#fff,rx:10
    classDef service fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff,rx:5
    
    User["👤 User<br/>Browser"]:::user
    CF["☁️ Cloudflare"]:::cloud
    Tunnel["🌐 Cloudflared"]:::tunnel
    EG["🚪 Envoy<br/>External"]:::gateway
    SVC["🔗 Service"]:::service
    Pod["📦 Pod"]:::service
    
    User --"HTTPS"--> CF
    CF --"Tunnel"--> Tunnel
    Tunnel --"HTTPS"--> EG
    EG --"HTTP"--> SVC
    SVC --"Connect"--> Pod
```

### Internal Access (Home Network)

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart LR
    %% Styles
    classDef user fill:#6c757d,stroke:#adb5bd,stroke-width:2px,color:#fff,rx:10
    classDef dns fill:#7b2cbf,stroke:#9d4edd,stroke-width:3px,color:#fff,rx:10
    classDef gateway fill:#9d0208,stroke:#d00000,stroke-width:3px,color:#fff,rx:10
    classDef service fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff,rx:5
    
    Laptop["💻 Laptop"]:::user
    DNS["🕸️ k8s-gateway<br/>10.0.40.153"]:::dns
    EGInt["🚪 Envoy<br/>Internal"]:::gateway
    SVC["🔗 Service"]:::service
    Pod["📦 Pod"]:::service
    
    Laptop --"DNS Query"--> DNS
    DNS --"A Record"--> EGInt
    Laptop --"HTTPS"--> EGInt
    EGInt --"HTTP"--> SVC
    SVC --"Connect"--> Pod
```

### Admin Access

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart LR
    %% Styles
    classDef admin fill:#2d6a4f,stroke:#40916c,stroke-width:2px,color:#fff,rx:10
    classDef vip fill:#7b2cbf,stroke:#9d4edd,stroke-width:3px,color:#fff,rx:10
    classDef api fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff,rx:5
    
    Admin["👨‍💻 Admin<br/>Local Machine"]:::admin
    VIP["🎯 VIP<br/>10.0.40.101"]:::vip
    API["☸️ Kube API"]:::api
    Talos["🖥️ Talos API"]:::api
    
    Admin --"kubectl"--> VIP
    Admin --"talosctl"--> Talos
    VIP --"Auth"--> API
    Talos --"Auth"--> API
```

## Application Deployment Flow

```mermaid
%%{init: {'theme': 'dark'}}%%
flowchart TB
    %% Styles
    classDef startend fill:#7b2cbf,stroke:#9d4edd,stroke-width:3px,color:#fff,rx:10
    classDef step fill:#023e8a,stroke:#0077b6,stroke-width:2px,color:#fff,rx:10
    classDef action fill:#2d6a4f,stroke:#40916c,stroke-width:2px,color:#fff,rx:5
    
    Start[("🚀 Add New<br/>Application")]:::startend
    
    subgraph Step1["📁 1. Create App Files"]
        D1["mkdir apps/ns/app"]:::action
        V1["values.yaml"]:::action
        S1["values.sops.yaml"]:::action
    end
    
    Step1 --> Step2
    
    subgraph Step2["⚡ 2. Create Argo App"]
        A1["argo/apps/ns/app.yaml"]:::action
    end
    
    Step2 --> Step3
    
    subgraph Step3["🚪 3. Expose (Optional)"]
        R1["HTTPRoute<br/>envoy-external"]:::action
        R2["HTTPRoute<br/>envoy-internal"]:::action
    end
    
    Step3 --> Step4
    
    subgraph Step4["📤 4. Commit & Push"]
        Git["git add<br/>git commit<br/>git push"]:::action
    end
    
    Step4 --> End[("✅ Auto Deploy<br/>by Argo CD")]:::startend
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
%%{init: {'theme': 'dark'}}%%
flowchart TB
    %% Styles
    classDef issue fill:#d00000,stroke:#ff0000,stroke-width:3px,color:#fff,rx:10
    classDef check fill:#7b2cbf,stroke:#9d4edd,stroke-width:2px,color:#fff,rx:5
    classDef analyze fill:#e85d04,stroke:#f48c06,stroke-width:2px,color:#fff,rx:5
    classDef fix fill:#2d6a4f,stroke:#40916c,stroke-width:2px,color:#fff,rx:5
    
    Issue[("❌ Issue<br/>Reported")]:::issue
    
    subgraph Check["🔍 Diagnostic Steps"]
        C1["kubectl get pods -A"]:::check
        C2["kubectl get events"]:::check
        C3["argocd app list"]:::check
        C4["cilium status"]:::check
    end
    
    Check --> Analyze
    
    subgraph Analyze["⚠️ Common Causes"]
        A1["Pod Crash"]:::analyze
        A2["Network Policy"]:::analyze
        A3["Sync Error"]:::analyze
        A4["Config Issue"]:::analyze
    end
    
    Analyze --> Fix
    
    subgraph Fix["✅ Resolution"]
        F1["kubectl logs<br/>kubectl describe"]:::fix
        F2["argocd app sync"]:::fix
        F3["Check YAML<br/>Check Secrets"]:::fix
    end
```
