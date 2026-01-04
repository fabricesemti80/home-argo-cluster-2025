# OpenTofu root configuration for Talos cluster deployment
# Uses the talos module to manage cluster provisioning
# Reference: https://xoid.net/2024/07/27/talos-terraform-proxmox.html

module "talos" {
  source = "./modules/talos"

  cluster_name      = var.cluster_name
  talos_version     = var.talos_version
  kubernetes_version = var.kubernetes_version
  nodes             = var.nodes
  cluster_endpoint  = var.cluster_api_addr
  gateway           = var.gateway
  cidr_prefix       = var.cidr_prefix
  dns_servers       = var.dns_servers
  ntp_servers       = var.ntp_servers
  talos_image_type  = var.talos_image_type

  proxmox_endpoint      = var.proxmox_endpoint
  proxmox_insecure      = var.proxmox_insecure
  proxmox_token_id      = var.proxmox_token_id
  proxmox_token_secret  = var.proxmox_token_secret
  storage_pool          = var.storage_pool
}
