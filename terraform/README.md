# OpenTofu Talos VM Deployment

This directory contains OpenTofu configuration for provisioning Talos Linux VMs on Proxmox infrastructure with automatic static IP configuration.

## Overview

This configuration uses a modular approach to automate the creation of Talos Linux virtual machines across multiple Proxmox hosts with automatic machine configuration and cluster bootstrap.

**Key Features:**

- Modular Terraform structure (talos module)
- Automatic machine configuration with static IPs
- Multi-host VM distribution across Proxmox nodes
- Talos 1.7.x support with cloud-init compatibility
- Automatic cluster bootstrap and kubeconfig export
- Configurable CPU, memory, and disk resources
- Reference: [xoid.net Talos Terraform Proxmox](https://xoid.net/2024/07/27/talos-terraform-proxmox.html)

## Prerequisites

- OpenTofu 1.6 or later
- Proxmox 7.0 or later
- Proxmox API token with appropriate permissions
- Talos 1.7.x schematic ID from [factory.talos.dev](https://factory.talos.dev)
- **IMPORTANT:** talosctl version must match Talos image version
  - If using Talos 1.7.x images, you must have talosctl 1.7.x
  - If using Talos 1.8.x images, you must have talosctl 1.8.x
  - Mismatched versions will cause configuration apply failures

### Proxmox API Token Setup

1. Log in to Proxmox UI
2. Navigate to **Datacenter > Permissions > API Tokens**
3. Create a new token with these permissions:
   - `Datastore.AllocateSpace`
   - `Datastore.Audit`
   - `VM.Allocate`
   - `VM.Clone`
   - `VM.Config.CDROM`
   - `VM.Config.CPU`
   - `VM.Config.Disk`
   - `VM.Config.Memory`
   - `VM.Config.Network`
   - `VM.Console`
   - `VM.Monitor`
   - `VM.PowerMgmt`

4. Save the token ID and secret securely

## Configuration

### 1. Proxmox Settings (proxmox.auto.tfvars)

Configure your Proxmox connection details:

```hcl
proxmox_endpoint      = "https://10.0.40.11:8006"
proxmox_insecure      = true
proxmox_token_id      = "terraform@pve!terraform"
proxmox_token_secret  = "your-token-secret-here"
```

### 2. Node Configuration (nodes.auto.tfvars)

Define your Talos nodes with static IP addresses:

```hcl
nodes = [
  {
    name         = "k8s-ctrl-01"
    address      = "10.0.40.90"
    controller   = true
    mac_address  = ""
    schematic_id = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
    cpu_cores    = 2
    memory_mb    = 2048
    disk_size_gb = 10
    mtu          = 1500
    vm_id        = 1090
    proxmox_node = "pve-0"
  },
  {
    name         = "k8s-ctrl-02"
    address      = "10.0.40.91"
    controller   = true
    mac_address  = ""
    schematic_id = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
    cpu_cores    = 2
    memory_mb    = 2048
    disk_size_gb = 10
    mtu          = 1500
    vm_id        = 1091
    proxmox_node = "pve-1"
  },
  {
    name         = "k8s-ctrl-03"
    address      = "10.0.40.92"
    controller   = true
    mac_address  = ""
    schematic_id = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
    cpu_cores    = 2
    memory_mb    = 2048
    disk_size_gb = 10
    mtu          = 1500
    vm_id        = 1092
    proxmox_node = "pve-2"
  }
]

gateway           = "10.0.40.1"
cidr_prefix       = 24
cluster_name      = "talos-cluster"
cluster_api_addr  = "10.0.40.90"
dns_servers       = ["1.1.1.1", "1.0.0.1"]
ntp_servers       = ["time.cloudflare.com"]
```

**Important Fields:**

- `schematic_id`: Talos 1.7.x schematic ID from [factory.talos.dev](https://factory.talos.dev)
- `address`: Static IP address (will be configured automatically)
- `controller`: `true` for control plane, `false` for workers
- `proxmox_node`: Proxmox node name for VM placement (pve-0, pve-1, pve-2)
- `vm_id`: Unique Proxmox VM ID

### 3. Cluster Settings

Configure cluster parameters in `nodes.auto.tfvars`:

```hcl
cluster_name      = "talos-cluster"
cluster_api_addr  = "10.0.40.90"  # First control plane IP or VIP
talos_version     = "v1.7.7"
kubernetes_version = "v1.31.0"
```

## Automatic Static IP Configuration

This configuration automatically applies static IPs to nodes using the Talos provider. The process:

1. VMs boot from ISO with DHCP
2. Talos provider generates machine configuration with static IPs
3. Configuration is applied to nodes automatically
4. Nodes reboot and apply static IPs
5. Cluster is bootstrapped automatically
6. Kubeconfig is exported

## Deployment Steps

### 1. Prepare Configuration Files

Ensure you have configured:

- `proxmox.auto.tfvars` - Proxmox connection details
- `nodes.auto.tfvars` - Node definitions with static IPs

### 2. Initialize OpenTofu

```bash
task tofu:init
```

### 3. Validate Configuration

```bash
task tofu:validate
```

### 4. Plan Deployment

```bash
task tofu:plan
```

Review the plan to verify:
- Correct number of VMs
- Correct resource allocation
- Correct Proxmox node placement
- Correct static IP assignments

### 5. Apply Configuration

```bash
task tofu:apply
```

This will:
1. Download Talos ISO to each Proxmox node
2. Create VMs across specified Proxmox hosts
3. Boot VMs from ISO
4. Apply machine configuration with static IPs
5. Bootstrap the cluster
6. Export kubeconfig

**Note:** This process takes 5-10 minutes. The Talos provider will:
- Wait for nodes to boot
- Apply machine configuration
- Wait for nodes to apply static IPs
- Bootstrap the cluster
- Export kubeconfig

### 6. Verify Cluster

After deployment completes:

```bash
# Get kubeconfig
terraform output -raw kubeconfig > kubeconfig.yaml

# Verify cluster is ready
kubectl --kubeconfig=kubeconfig.yaml get nodes

# Check Talos nodes
talosctl --talosconfig=<(terraform output -raw talos_client_configuration) health
```

### 7. Destroy Resources

```bash
task tofu:destroy
```

## Multi-Host Distribution

VMs are automatically distributed across Proxmox hosts by specifying different `proxmox_node` values in `nodes.auto.tfvars`:

```hcl
nodes = [
  { name = "k8s-ctrl-01", proxmox_node = "pve-0", ... },
  { name = "k8s-ctrl-02", proxmox_node = "pve-1", ... },
  { name = "k8s-ctrl-03", proxmox_node = "pve-2", ... },
]
```

## Important: Version Matching

**Talos image version MUST match talosctl version**

If you encounter errors like "configuration apply failed" or "node not responding", check:

```bash
# Check your talosctl version
talosctl version

# Check the Talos version in nodes.auto.tfvars
grep talos_version terraform/nodes.auto.tfvars
```

They must match! For example:
- talosctl v1.7.7 → use Talos v1.7.7 images
- talosctl v1.8.0 → use Talos v1.8.0 images

If they don't match, update `talos_version` in `nodes.auto.tfvars` to match your talosctl version.

## Troubleshooting

### Configuration Apply Timeout

**Issue:** `talos_machine_configuration_apply` times out

**Symptoms:**
- Still creating after 10+ minutes
- Nodes not reachable on port 50000

**Solution:**
1. Verify nodes are running in Proxmox console
2. Check nodes have network connectivity
3. Verify firewall allows port 50000
4. Increase timeout in `modules/talos/main.tf` if needed

### Nodes Not Getting Static IPs

**Issue:** Nodes still have DHCP IPs after deployment

**Solution:**
1. Verify schematic ID is Talos 1.7.x (not 1.8.0+)
2. Check machine configuration was applied: `talosctl -n <ip> get machineconfig`
3. Check network interfaces: `talosctl -n <ip> get addresses`
4. Check logs: `talosctl -n <ip> logs controller-runtime`

### VMs All on Same Host

**Issue:** All VMs created on one Proxmox node

**Solution:**
1. Specify `proxmox_node` for each VM in `nodes.auto.tfvars`
2. Use different node names (pve-0, pve-1, pve-2)
3. Verify Proxmox node names: `pvesh get /nodes`

### ISO Download Failures

**Issue:** Terraform fails to download ISO

**Solution:**
1. Verify internet connectivity
2. Check schematic ID is valid at factory.talos.dev
3. Verify Talos version matches (v1.7.7)
4. Check Proxmox datastore has sufficient space

### Proxmox API Errors

**Issue:** Authentication or permission errors

**Solution:**
1. Verify credentials in `proxmox.auto.tfvars`
2. Check API token has required permissions
3. Verify Proxmox endpoint URL is correct
4. Test connectivity: `curl -k https://proxmox-host:8006/api2/json/version`

### Cluster Bootstrap Fails

**Issue:** `talos_machine_bootstrap` fails

**Solution:**
1. Ensure all control plane nodes are healthy: `talosctl -n <ip> health`
2. Verify cluster endpoint is correct in `nodes.auto.tfvars`
3. Check nodes can reach each other
4. Try bootstrap again after waiting a few minutes

## File Structure

```
terraform/
├── main.tf                      # Root configuration (uses talos module)
├── variables.tf                 # Root variable definitions
├── versions.tf                  # OpenTofu and provider versions
├── outputs.tf                   # Root output definitions
├── proxmox.auto.tfvars          # Proxmox configuration
├── nodes.auto.tfvars            # Node definitions with static IPs
├── modules/
│   └── talos/
│       ├── main.tf              # Talos module resources
│       ├── variables.tf          # Module variable definitions
│       ├── versions.tf           # Module provider requirements
│       └── outputs.tf            # Module output definitions
├── .terraform/                  # OpenTofu working directory (auto-generated)
├── .terraform.lock.hcl          # Provider lock file
├── terraform.tfstate            # State file (auto-generated)
├── README.md                    # This file
└── MANUAL_TALOS_SETUP.md        # Manual setup guide (legacy)
```

## Security Considerations

- **Never commit sensitive values** to version control:
  - `proxmox_token_secret`
  - `terraform.tfstate`
  - `terraform.tfstate.backup`

- **Use environment variables** for sensitive data:
  ```bash
  export TF_VAR_proxmox_token_secret="your-secret"
  ```

- **Restrict API token permissions** to minimum required

- **Use TLS certificates** in production (`proxmox_insecure = false`)

## Next Steps

After deployment completes successfully:

1. **Verify Cluster:**

   ```bash
   # Export kubeconfig
   terraform output -raw kubeconfig > kubeconfig.yaml

   # Check nodes are ready
   kubectl --kubeconfig=kubeconfig.yaml get nodes

   # Check Talos nodes
   talosctl --talosconfig=<(terraform output -raw talos_client_configuration) health
   ```

2. **Bootstrap Applications:**

   ```bash
   task bootstrap:apps
   ```

3. **Monitor Cluster:**

   ```bash
   kubectl --kubeconfig=kubeconfig.yaml get pods -A
   ```

## Module Architecture

The `talos` module handles:

- **Talos Secrets Generation:** Creates cluster secrets for secure communication
- **Machine Configuration:** Generates control plane and worker configurations with static IPs
- **ISO Download:** Downloads Talos ISO for each Proxmox node
- **VM Creation:** Creates VMs across specified Proxmox hosts
- **Configuration Application:** Applies machine configuration to nodes
- **Cluster Bootstrap:** Bootstraps the Kubernetes cluster
- **Kubeconfig Export:** Exports kubeconfig for kubectl access

## References

- [xoid.net: Talos Terraform Proxmox](https://xoid.net/2024/07/27/talos-terraform-proxmox.html)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Proxmox Terraform Provider](https://github.com/bpg/terraform-provider-proxmox)
- [Talos Linux Documentation](https://www.talos.dev/)
- [Talos v1.7 Documentation](https://www.talos.dev/v1.7/)
