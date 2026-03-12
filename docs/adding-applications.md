# Adding Applications

This guide walks you through adding a new application to your Kubernetes cluster using GitOps with Argo CD.

## Overview

Applications in this cluster are managed through Argo CD and consist of three main components:

1. **Helm Values** - Configuration for the Helm chart (`kubernetes/apps/<namespace>/<app>/values.yaml`)
2. **Secrets** - Encrypted sensitive values (`kubernetes/apps/<namespace>/<app>/values.sops.yaml`)
3. **Argo Application** - Tells Argo CD how to deploy (`kubernetes/argo/apps/<namespace>/<app>.yaml`)

## Step-by-Step Guide

### 1. Create the Application Directory

Create a new directory for your application under `kubernetes/apps/<namespace>/`:

```sh
mkdir -p kubernetes/apps/<namespace>/<app>
```

Where:
- `<namespace>` is the Kubernetes namespace (e.g., `default`, `monitoring`, `media`)
- `<app>` is your application name (e.g., `echo`, `prometheus`, `vault`)

### 2. Create Helm Values

Create a `values.yaml` file with your application configuration. Use the [app-template](https://github.com/bjw-s-labs/helm-charts/tree/main/charts/app-template) chart as a base:

```yaml
controllers:
  <app>:
    strategy: RollingUpdate
    containers:
      app:
        image:
          repository: ghcr.io/example/image
          tag: latest
        env:
          KEY: value
        probes:
          liveness: &probes
            enabled: true
            custom: true
            spec:
              httpGet:
                path: /healthz
                port: 8080
              initialDelaySeconds: 0
              periodSeconds: 10
              timeoutSeconds: 1
              failureThreshold: 3
          readiness: *probes
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities: { drop: ["ALL"] }
        resources:
          requests:
            cpu: 10m
            memory: 64Mi
          limits:
            memory: 128Mi
defaultPodOptions:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
service:
  app:
    controller: <app>
    ports:
      http:
        port: 8080
```

### 3. Create Encrypted Secrets (Optional)

If your application needs secrets, create a `values.sops.yaml` file:

```sh
# Decrypt an existing sops file to get the format
sops -d kubernetes/apps/default/echo/values.sops.yaml
```

Then create your encrypted version:

```yaml
controllers:
  <app>:
    containers:
      app:
        envFrom:
          - secretRef:
              name: my-secret
```

Encrypt it:

```sh
sops --encrypt --age age1saea3t7l67lavg0ardepzys6egp50g82uvks98pk53xdlj57uf8sa2arcs \
  --encrypted-regex '^(data|stringData)$' \
  --input-type yaml \
  --output kubernetes/apps/<namespace>/<app>/values.sops.yaml \
  kubernetes/apps/<namespace>/<app>/values.sops.yaml
```

### 4. Create the Argo Application Manifest

Create `kubernetes/argo/apps/<namespace>/<app>.yaml`:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app>
  namespace: argo-system
  annotations:
    argocd.argoproj.io/sync-wave: '0'
spec:
  project: kubernetes
  sources:
    - repoURL: "https://github.com/<your-org>/<your-repo>.git"
      path: kubernetes/apps/<namespace>/<app>
      targetRevision: main
      ref: repo
    - repoURL: ghcr.io/bjw-s-labs/helm
      chart: app-template
      targetRevision: 4.6.2
      helm:
        releaseName: <app>
        valueFiles:
          - $repo/kubernetes/apps/<namespace>/<app>/values.yaml
          - $repo/kubernetes/apps/<namespace>/<app>/values.sops.yaml
  destination:
    name: in-cluster
    namespace: <namespace>
  syncPolicy:
    automated:
      allowEmpty: true
      prune: true
      selfHeal: true
    retry:
      limit: 1
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true
      - PruneLast=true
      - RespectIgnoreDifferences=true
```

### 5. Expose the Application (Optional)

#### Internal Access Only

To make the app accessible only within your network, create an HTTPRoute referencing the `envoy-internal` gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app>
  namespace: <namespace>
spec:
  parentRefs:
    - name: envoy-internal
      namespace: network
  hostnames:
    - "<app>.krapulax.dev"
  rules:
    - backendRefs:
        - name: <app>
          port: 80
      matches:
        - path:
            type: PathPrefix
            value: /
```

#### Public Access

To make the app publicly accessible via Cloudflare Tunnel, reference `envoy-external`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app>
  namespace: <namespace>
spec:
  parentRefs:
    - name: envoy-external
      namespace: network
  hostnames:
    - "<app>.krapulax.dev"
  rules:
    - backendRefs:
        - name: <app>
          port: 80
      matches:
        - path:
            type: PathPrefix
            value: /
```

Add this HTTPRoute to your app's kustomization or include it in the Argo Application sources.

### 6. Commit and Sync

```sh
git add -A
git commit -m "feat: add <app> application"
git push
```

Argo CD will automatically detect the changes and deploy your application. To force an immediate sync:

```sh
task reconcile
```

## Example: Adding a Test Application

Here's a complete example of adding a simple echo application:

```sh
# 1. Create directory
mkdir -p kubernetes/apps/default/myapp

# 2. Create values.yaml (copy from echo example and modify)
# 3. Create values.sops.yaml if needed
# 4. Create kubernetes/argo/apps/default/myapp.yaml
# 5. Commit and push
```

## Troubleshooting

- **Application not syncing**: Run `argocd app list` to check status
- **Pod failing**: Check logs with `kubectl logs -n <namespace> <pod-name>`
- **Route not working**: Verify HTTPRoute is attached to the correct gateway
- **Secrets not decrypting**: Ensure you have the age key and sops is configured

## Useful Commands

```sh
# List all applications
argocd app list -A

# Get application details
argocd app get <app>

# Force sync
argocd app sync <app>

# View application logs
argocd app logs <app>

# Delete application (if needed)
argocd app delete <app>
```
