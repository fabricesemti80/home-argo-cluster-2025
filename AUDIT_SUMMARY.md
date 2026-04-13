# Kubernetes Apps Resource & Probe Audit Summary

**Date**: March 18, 2026  
**Status**: 🔴 Critical issues found - OOM risk on Prometheus

---

## Critical Findings

| App | Issue | Current Usage | Requested | Limit | Risk |
|---|---|---|---|---|---|
| **prometheus** | NO memory limit | 1059Mi | 256Mi | ❌ None | 🔴 OOM |
| **grafana** | NO resource config | 309Mi | ❌ None | ❌ None | 🟡 OOM |
| **argo-cd repo** | NO resource config | 54-104Mi | ❌ None | ❌ None | 🟡 Unstable |
| **cilium** | NO resource config | 121-287Mi | ❌ None | ❌ None | 🟡 Critical system |
| **coredns** | NO resource config | 55-58Mi | ❌ None | ❌ None | 🟡 Critical system |

---

## Apps Needing Updates

### 🔴 CRITICAL (OOM Risk)

1. **prometheus** (monitoring/kube-prometheus-stack)
   - Current: 1059Mi, Request: 256Mi, **No Limit**
   - Fix: Limit: 1.5Gi (4x current usage), Request: 512Mi

2. **grafana** (monitoring/kube-prometheus-stack)
   - Current: 309Mi, **No Config**
   - Fix: Request: 256Mi, Limit: 512Mi

### 🟡 HIGH (System-Critical or Unstable Probes)

3. **argo-cd components** (argo-system/argo-cd)
   - appctl: 440Mi + 84Mi, **No resource config**
   - reposerver: 54-104Mi, **No config**
   - Probes: Some have 0s initialDelay (risky)
   - Fix: Add resource limits, fix probe delays

4. **cilium** (kube-system/cilium)
   - Current: 121-287Mi per pod, **No config**
   - Critical CNI - cannot OOM
   - Fix: Request: 200Mi, Limit: 512Mi per pod

5. **coredns** (kube-system/coredns)
   - Current: 55-58Mi, **No config**
   - Critical DNS - cannot fail
   - Fix: Request: 64Mi, Limit: 256Mi

6. **metrics-server** (kube-system/metrics-server)
   - Current: 65Mi, **No config**
   - Fix: Request: 64Mi, Limit: 256Mi

7. **spegel** (kube-system/spegel)
   - Current: 15-33Mi, **No config**
   - Fix: Request: 32Mi, Limit: 256Mi

8. **cloudflare-tunnel** (network/cloudflare-tunnel)
   - Current: 30Mi, Has limits (256Mi)
   - Probes: initialDelaySeconds=0 (risky)
   - Fix: initialDelaySeconds=5, timeoutSeconds=3, failureThreshold=5

9. **cloudflare-dns** (network/cloudflare-dns)
    - Current: 31Mi, **No config**
    - Fix: Request: 32Mi, Limit: 256Mi

10. **k8s-gateway** (network/k8s-gateway)
    - Current: 18Mi, **No config**
    - Fix: Request: 32Mi, Limit: 128Mi

11. **doppler-operator** (doppler-operator-system/doppler-operator)
    - Current: 22Mi, **No config**
    - Fix: Request: 32Mi, Limit: 256Mi

12. **reloader** (kube-system/reloader)
    - Current: 31Mi, **No config**
    - Fix: Request: 32Mi, Limit: 128Mi

13. **cert-manager** (cert-manager/cert-manager)
    - Current: 70/45/21Mi, **No config**
    - Fix: Add resource limits

14. **echo** (default/echo)
    - ✅ Already fixed in latest commit

---

## Probe Configuration Standards

### Recommended Settings

| Component Type | initialDelaySeconds | timeoutSeconds | failureThreshold | periodSeconds |
|---|---|---|---|---|
| Fast startup (API) | 5 | 3 | 5 | 10 |
| Medium startup (App) | 10 | 3 | 5 | 15 |
| Slow startup (JVM/DB) | 30+ | 5 | 5 | 20 |
| System-critical (DNS, CNI) | 10 | 3 | 10 | 10 |

### Current Issues Found:
- **9 apps** have `initialDelaySeconds: 0` (too aggressive)
- **8 apps** have `timeoutSeconds: 1` (may timeout on slow networks)
- **6 apps** have `failureThreshold: 3` (too strict)

---

## Actual Pod Usage (kubectl top pods -A)

```
prometheus-0:           1059Mi  (4.1x requested)
grafana:                 309Mi  (no limits)
argo-appctl-0:           440Mi  (no limits)
cilium nodes:        121-287Mi  (no limits)
envoy-external-2:        153Mi  (no limits)
argo-appctl-1:            84Mi  (no limits)
kube-apiserver-03:       1679Mi (system-managed)
argo-reposerver:      54-104Mi  (no limits)
```

---

## Implementation Plan

### Phase 1: Critical Fixes (Same Day)
1. Prometheus: 256Mi → 1.5Gi limit + 512Mi request
2. Grafana: Add 256Mi request, 512Mi limit
3. Cilium: Add 200Mi request, 512Mi limit (DaemonSet)

### Phase 2: System-Critical (Next)
4. Argo-CD: All components - add resource limits
5. CoreDNS: Add 64Mi request, 256Mi limit
6. metrics-server: Add 64Mi request, 256Mi limit
7. spegel: Add 32Mi request, 256Mi limit

### Phase 3: Networking (Day 2)
8. cloudflare-tunnel: Fix probe timings + add memory request
9. cloudflare-dns: Add resource limits
10. k8s-gateway: Add resource limits
11. envoy-gateway: Add resource limits

### Phase 4: Misc (Day 2)
12. doppler-operator: Add resource limits
13. reloader: Add resource limits
14. cert-manager: Add resource limits

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Prometheus OOM during spike | HIGH | Monitoring down | Increase limit to 1.5Gi |
| Cilium OOM → network failure | MEDIUM | Cluster down | Critical: limit must be high |
| Argo-CD instability | MEDIUM | GitOps fails | Add resource mgmt + probe tuning |
| DNS failures (CoreDNS) | LOW | Pod DNS fails | Protect with resource requests |

---

## Files to Update

```
kubernetes/apps/monitoring/kube-prometheus-stack/values.yaml
kubernetes/apps/argo-system/argo-cd/values.yaml
kubernetes/apps/kube-system/cilium/values.yaml
kubernetes/apps/kube-system/coredns/values.yaml
kubernetes/apps/kube-system/metrics-server/values.yaml
kubernetes/apps/kube-system/reloader/values.yaml
kubernetes/apps/kube-system/spegel/values.yaml
kubernetes/apps/network/cloudflare-tunnel/values.yaml
kubernetes/apps/network/cloudflare-dns/values.yaml
kubernetes/apps/network/k8s-gateway/values.sops.yaml
kubernetes/apps/cert-manager/cert-manager/values.yaml
kubernetes/apps/doppler-operator-system/doppler-operator/values.yaml
kubernetes/apps/network/envoy-gateway/config/envoy.sops.yaml
```

---

## Next Steps

1. **Approve changes** - Review and confirm risk/benefit
2. **Apply fixes** - Update values files in priority order
3. **Test** - Monitor metrics during application
4. **Validate** - Verify pods restart cleanly and stay healthy
5. **Document** - Update runbooks/ops guides

---

## Notes

- System pods (kube-apiserver, kubelet, etc) are managed by Talos/kubelet and have OS-level resource management
- Helm chart defaults may override YAML configs - check chart values during apply
- Probe timeouts are independent of resource limits but affect stability perception
- Memory requests affect scheduler decisions; limits prevent OOM kills
