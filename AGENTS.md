# AGENTS.md - Guidance for Agentic Coding Agents

This project is a **GitOps-managed Kubernetes homelab** using Talos Linux, Argo CD, and Helm. All cluster state is declarative and version-controlled.

## Project Overview

| Layer | Technology |
|---|---|
| OS | Talos Linux (immutable, API-driven) |
| Kubernetes | Talos-managed via talhelper |
| CNI | Cilium |
| DNS | CoreDNS (in-cluster), k8s-gateway (split DNS) |
| GitOps | Argo CD |
| Ingress | Envoy Gateway (internal + external gateways) |
| TLS | cert-manager |
| External DNS | external-dns via Cloudflare |
| Tunnel | cloudflared (Cloudflare Tunnel) |
| Image Cache | Spegel (peer-to-peer registry mirror) |
| Config Reload | Reloader |
| Metrics | metrics-server |
| Secrets | SOPS with age encryption |
| Templating | makejinja |
| IaC | Terraform/OpenTofu (optional VM provisioning) |
| Task Runner | Task (`go-task`) |
| Tool Management | mise |
| Dependency Updates | Renovate |

## Cluster Topology

- **3 controller nodes** (`k8s-ctrl-01..03`) on `10.0.40.90-92` — run control plane + workloads
- **3 worker nodes** (`k8s-wrkr-01..03`) on `10.0.40.93-95`
- **VIP** (Kube API): `10.0.40.101`
- **Internal gateway**: `10.0.40.102`
- **External gateway** (Cloudflare): `10.0.40.103`
- **DNS gateway** (k8s-gateway): `10.0.40.153`
- **Domain**: `k8s.krapulax.dev`
- **Pod CIDR**: `10.42.0.0/16` — **Service CIDR**: `10.43.0.0/16`

---

## Build / Lint / Test Commands

All operations use **Task targets**. Run `task --list` to see all available commands.

### Core Commands

```sh
# Initialize project (generate cluster.yaml, nodes.yaml, age key, deploy keys)
task init

# Render templates and validate configuration
task configure

# Force Argo CD to sync all applications
task reconcile
```

### Bootstrap

```sh
# Bootstrap Talos cluster (secrets, genconfig, apply, etcd, kubeconfig)
task bootstrap:talos

# Install core apps via helmfile (cilium → coredns → spegel → cert-manager → argo-cd)
task bootstrap:apps
```

### Talos Maintenance

```sh
# Generate Talos configuration from talconfig.yaml
task talos:generate-config

# Apply Talos config to a node (requires IP variable)
task talos:apply-node IP=10.0.40.90 MODE=auto

# Upgrade Talos on a single node (requires IP variable)
task talos:upgrade-node IP=10.0.40.90

# Upgrade Kubernetes version cluster-wide
task talos:upgrade-k8s

# Reset all nodes back to maintenance mode (DESTRUCTIVE)
task talos:reset
```

### Terraform/OpenTofu

```sh
# Initialize OpenTofu
task tofu:init

# Validate OpenTofu configuration
task tofu:validate

# Generate execution plan
task tofu:plan

# Apply configuration to create VMs
task tofu:apply

# Destroy VMs and resources
task tofu:destroy
```

### Template Validation

```sh
# Validate Kubernetes manifests with kubeconform (auto during `task configure`)
# Validate Talos configuration (auto during `task configure`)
# Validate schemas with CUE (auto during `task configure` when templates exist)
```

### Debugging

```sh
# Gather common Kubernetes resources for debugging
task template:debug
```

### All Task Targets Reference

| Task | Description | Required vars |
|---|---|---|
| `task init` | Initialize cluster.yaml, nodes.yaml, age key, deploy key, push token | — |
| `task configure` | Render templates, encrypt secrets, validate configs | — |
| `task reconcile` | Force Argo CD to sync all apps from Git | argocd login |
| `task bootstrap:talos` | Bootstrap Talos cluster | — |
| `task bootstrap:apps` | Install core apps via helmfile | — |
| `task talos:generate-config` | Regenerate Talos node configs | — |
| `task talos:apply-node` | Apply Talos config to a node | `IP`, `MODE` (optional) |
| `task talos:upgrade-node` | Upgrade Talos on a single node | `IP` |
| `task talos:upgrade-k8s` | Upgrade Kubernetes version | — |
| `task talos:reset` | Reset all nodes (destructive) | — |
| `task template:debug` | Gather K8s resources for debugging | — |
| `task template:tidy` | Archive template files | — |
| `task template:reset` | Remove templated files (destructive) | — |
| `task tofu:init` | Initialize OpenTofu | — |
| `task tofu:validate` | Validate OpenTofu config | — |
| `task tofu:plan` | Generate execution plan | — |
| `task tofu:apply` | Apply config to create VMs | — |
| `task tofu:destroy` | Destroy VMs (destructive) | — |

---

## Code Style Guidelines

### General Principles

1. **Task-first administration**: All cluster operations MUST use Task targets. Avoid direct `kubectl`, `helm`, `talosctl`, or `tofu` commands unless absolutely necessary for debugging.
2. **Declarative state**: All configuration is declarative YAML. No imperative commands that modify state.
3. **Secrets handling**: All secrets use SOPS-encrypted `.sops.yaml` files with age encryption.
4. **Administration via Taskfiles only**: Wrap any new operational procedure in a Task target before documenting it.

### YAML Conventions

- **File structure**: Use `---` document separator at the start of every YAML file
- **Indentation**: 2 spaces (enforced by SOPS config)
- **Quotes**: Use quotes for strings that could be interpreted as booleans or numbers
- **Trailing spaces**: Remove trailing whitespace
- **Comments**: Use minimal comments; prefer self-documenting structure

```yaml
# Good
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cilium
  namespace: argo-system

# Avoid
apiVersion: argoproj.io/v1alpha1   # Argo CD API version
kind: Application                  # Application resource
```

### Kubernetes Resources

- **Naming**: Use lowercase with hyphens (kebab-case)
- **Annotations**: Use for Argo CD sync waves, metadata
- **Labels**: Use for app identification, selectors
- **Server-side apply**: Always use `--server-side` for kubectl/argocd apply

```yaml
metadata:
  name: my-app
  namespace: default
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # String for sync ordering
```

### Argo CD Applications

- One Application YAML per app in `kubernetes/argo/apps/<namespace>/`
- Include sync-wave annotations for ordering
- Use `allowEmpty: true` for optional components
- Use `selfHeal: true` for automatic reconciliation

```yaml
spec:
  syncPolicy:
    automated:
      allowEmpty: true
      prune: true
      selfHeal: true
```

### Helm Values

- Values files in `kubernetes/apps/<namespace>/<app>/values.yaml`
- SOPS-encrypted secrets in `values.sops.yaml`
- Use Kustomize overlays for environment-specific overrides

### Secrets (SOPS)

- **Full encryption** for `talos/` directory files
- **Selective encryption** (only `data`/`stringData` fields) for `bootstrap/`, `kubernetes/`, `secret/` files
- Age key at `age.key` (gitignored)
- Never commit unencrypted secrets

### Bash Scripts

- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -Eeuo pipefail`
- Functions for reusable logic
- Logging via `lib/common.sh` functions: `log info`, `log error`, etc.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"

function main() {
    check_env KUBECONFIG
    log info "Starting bootstrap"
}

main "$@"
```

### Terraform/OpenTofu

- Use OpenTofu (`tofu`) over Terraform
- Modules in `terraform/modules/`
- Variables with descriptions
- Output meaningful values for integration

### Naming Conventions

| Resource | Convention | Example |
|---|---|---|
| Files | kebab-case | `cloudflare-dns.yaml` |
| Namespaces | lowercase | `kube-system` |
| Applications | kebab-case | `cilium`, `argo-cd` |
| Helm releases | kebab-case | `cilium`, `coredns` |
| ConfigMaps | kebab-case | `cilium-config` |
| Secrets | kebab-case | `cloudflare-api-token` |

### Error Handling

- Use preconditions in Taskfiles for required tools/files
- Use `||` and `exit` for fatal errors in scripts
- Log with appropriate levels: `debug`, `info`, `warn`, `error`
- Provide actionable error messages with context

### Import/Dependency Management

- Tools managed via `.mise.toml` (mise)
- Use aqua for CLI tool versioning
- Helm dependencies installed via `mise run deps`

---

## Repository Structure

```
├── bootstrap/helmfile.d/     # Initial bootstrap (helmfile)
│   ├── 00-crds.yaml         # CRDs installed first
│   └── 01-apps.yaml         # Core apps
├── kubernetes/
│   ├── apps/                 # Helm values per namespace/app
│   │   ├── argo-system/      # Argo CD
│   │   ├── cert-manager/     # cert-manager
│   │   ├── default/         # echo (test app)
│   │   ├── kube-system/     # cilium, coredns, metrics-server, reloader, spegel
│   │   └── network/         # cloudflare-dns, cloudflare-tunnel, envoy-gateway, k8s-gateway
│   ├── argo/                 # Argo CD Application manifests
│   │   ├── apps/             # One YAML per app
│   │   ├── repositories/    # OCI/Git repo definitions
│   │   └── settings/         # AppProject, settings
│   └── components/           # Shared Kustomize components
├── talos/                    # Talos configuration
├── terraform/                # OpenTofu (optional)
├── templates/                # makejinja templates
├── scripts/                  # Helper scripts
├── .taskfiles/               # Task includes
├── cluster.yaml              # Cluster-wide settings
├── nodes.yaml                # Node inventory
└── Taskfile.yaml            # Main task definitions
```

---

## Conventions

- **Helm values** live in `kubernetes/apps/<namespace>/<app>/values.yaml`
- **Argo Application manifests** live in `kubernetes/argo/apps/<namespace>/<app>.yaml`
- **Secrets** use SOPS-encrypted files (`*.sops.yaml`) with age key (`age.key`)
- **SOPS rules**: `talos/` encrypts full file; `bootstrap/`/`kubernetes/` encrypt only `data`/`stringData`
- **Helm charts** are referenced as OCI artifacts (e.g., `oci://ghcr.io/`, `oci://quay.io/`)
- **Bootstrap ordering**: cilium (CNI) → coredns (DNS) → spegel → cert-manager → argo-cd
- **Container images** should use `registry.k8s.io` or `ghcr.io` over Docker Hub to avoid rate limits
- **Documentation structure**: `README.md` is the main entry point; link to `docs/<topic>.md` for detailed guides

---

## Testing

This project has no traditional unit tests. Validation is done via:

1. **Schema validation**: CUE schemas for cluster.yaml/nodes.yaml
2. **Kubeconform**: Validates Kubernetes manifests
3. **Talhelper validate**: Validates Talos configuration
4. **Argo CD sync**: Actual apply/diff against cluster

---

## Common Workflows

**Adding a new application:**

1. Create Helm values in `kubernetes/apps/<namespace>/<app>/values.yaml`
2. Create Argo Application in `kubernetes/argo/apps/<namespace>/<app>.yaml`
3. Run `task configure` to validate and encrypt
4. Commit and push; Argo CD syncs automatically

**Updating a Helm chart version:**

1. Update `targetRevision` in the Argo Application YAML
2. Commit and push; Argo CD handles the upgrade

---

## Important Notes

- **Do not confuse Helm chart OCI references with container image references**
- All CLI tools are pinned in `.mise.toml` — run `mise install` to get correct versions
- `kubeconfig`, `age.key`, `cloudflare-tunnel.json`, `github-deploy.key` are gitignored
- Use `task reconcile` after pushing changes to force Argo sync
- When significant changes are made to the cluster or infrastructure, document them in `docs/`
- **Templates are the source of truth**: Any change to a generated file under `kubernetes/` MUST also be applied to its corresponding template under `templates/`. Generated files are overwritten by `task configure` — template-only fixes are permanent, file-only fixes are not.

## Troubleshooting

See `docs/troubleshooting.md` for known issues and fixes.
