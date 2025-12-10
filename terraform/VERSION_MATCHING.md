# Talos Version Matching Guide

## Critical: Image Version Must Match talosctl Version

This is the most common issue when deploying Talos with Terraform.

**If your Talos image version doesn't match your talosctl version, configuration apply will fail.**

## How to Check

### 1. Check Your talosctl Version

```bash
talosctl version
```

Example output:
```
Client version: v1.7.7
```

### 2. Check Terraform Configuration

```bash
grep talos_version terraform/nodes.auto.tfvars
```

Example output:
```
talos_version = "v1.7.7"
```

### 3. Verify They Match

- talosctl v1.7.7 → talos_version = "v1.7.7" ✅
- talosctl v1.7.7 → talos_version = "v1.8.0" ❌ (WILL FAIL)
- talosctl v1.8.0 → talos_version = "v1.7.7" ❌ (WILL FAIL)

## If They Don't Match

### Option 1: Update Terraform to Match talosctl

If you have talosctl v1.8.0 but Terraform is set to v1.7.7:

```bash
# Edit nodes.auto.tfvars
# Change: talos_version = "v1.7.7"
# To:     talos_version = "v1.8.0"

# Then redeploy
task tofu:plan
task tofu:apply
```

### Option 2: Update talosctl to Match Terraform

If you have talosctl v1.7.7 but want to use v1.8.0 images:

```bash
# Update talosctl
talosctl upgrade

# Verify version
talosctl version

# Then update Terraform
# Edit nodes.auto.tfvars
# Change: talos_version = "v1.7.7"
# To:     talos_version = "v1.8.0"

# Then redeploy
task tofu:plan
task tofu:apply
```

## Generating Correct Schematic ID

When you generate a schematic ID at [factory.talos.dev](https://factory.talos.dev):

1. **Select the correct Talos version** (must match your talosctl)
2. Copy the schematic ID
3. Update `nodes.auto.tfvars`:

```hcl
nodes = [
  {
    schematic_id = "YOUR_NEW_SCHEMATIC_ID"  # From factory.talos.dev
    # ... other fields
  }
]

talos_version = "v1.8.0"  # Must match the version you selected
```

## Common Errors and Solutions

### Error: "Configuration apply failed"

**Cause:** Likely version mismatch

**Solution:**
1. Check talosctl version: `talosctl version`
2. Check Terraform version: `grep talos_version terraform/nodes.auto.tfvars`
3. Make them match
4. Redeploy

### Error: "Node not responding on port 50000"

**Cause:** Could be version mismatch or network issue

**Solution:**
1. First, verify version match (see above)
2. Check Proxmox console for VM boot messages
3. Verify network connectivity

### Error: "Talos API version mismatch"

**Cause:** Definitely version mismatch

**Solution:**
1. Update talosctl: `talosctl upgrade`
2. Update Terraform: `talos_version = "v1.X.X"` (match talosctl)
3. Redeploy

## Summary

| Component | Version | Source |
|-----------|---------|--------|
| talosctl | v1.7.7 | `talosctl version` |
| Talos image | v1.7.7 | `talos_version` in nodes.auto.tfvars |
| Schematic ID | v1.7.7 | Generated at factory.talos.dev |

**All three must match!**

## References

- [Talos Version Support Matrix](https://www.talos.dev/latest/introduction/support-matrix/)
- [Talos Factory](https://factory.talos.dev/)
- [talosctl Documentation](https://www.talos.dev/latest/reference/cli/)
