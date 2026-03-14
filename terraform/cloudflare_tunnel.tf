variable "cf_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cf_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}


variable "tunnel_name" {
  description = "Cloudflare tunnel name"
  type        = string
  default     = "kubernetes"
}

variable "tunnel_secret" {
  description = "Tunnel secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "doppler_token" {
  description = "Doppler token"
  type        = string
  sensitive   = true
}

provider "cloudflare" {
  api_token = var.cf_api_token
}

provider "doppler" {
  doppler_token = var.doppler_token
}

# Fetch Cloudflare configuration from Doppler
data "doppler_secrets" "cloudflare" {
  count   = var.doppler_token != "" ? 1 : 0
  config  = "dev"
  project = "home-argo-cluster-2025"
}

locals {
  cf_zone_id = var.doppler_token != "" ? data.doppler_secrets.cloudflare[0].map.CF_ZONE_ID : ""
}

# Tunnel Secret - use provided secret or generate new one
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

# Create the Tunnel
resource "cloudflare_tunnel" "tunnel" {
  account_id = var.cf_account_id
  name       = var.tunnel_name
  secret     = var.tunnel_secret != "" ? var.tunnel_secret : random_id.tunnel_secret.b64_std
}

# Tunnel Token for deployment
locals {
  actual_secret = var.tunnel_secret != "" ? var.tunnel_secret : random_id.tunnel_secret.b64_std
  tunnel_id     = cloudflare_tunnel.tunnel.id
  account_tag   = var.cf_account_id
  tunnel_token = base64encode(jsonencode({
    a = var.cf_account_id
    t = local.tunnel_id
    s = local.actual_secret
  }))
  credentials_json = jsonencode({
    AccountTag   = local.account_tag
    TunnelID     = local.tunnel_id
    TunnelSecret = local.actual_secret
    TunnelName   = var.tunnel_name
  })
}

resource "local_file" "credentials" {
  count    = var.doppler_token != "" ? 1 : 0
  content  = local.credentials_json
  filename = pathexpand("${path.module}/../cloudflare-tunnel.json")
}

resource "doppler_secret" "tunnel_credentials" {
  count      = var.doppler_token != "" ? 1 : 0
  config     = "dev"
  project    = "home-argo-cluster-2025"
  name       = "TUNNEL_CREDENTIALS"
  value      = local.credentials_json
  value_type = "json"
}

resource "doppler_secret" "tunnel_id" {
  count   = var.doppler_token != "" ? 1 : 0
  config  = "dev"
  project = "home-argo-cluster-2025"
  name    = "TUNNEL_ID"
  value   = local.tunnel_id
}

resource "doppler_secret" "tunnel_token" {
  count   = var.doppler_token != "" ? 1 : 0
  config  = "dev"
  project = "home-argo-cluster-2025"
  name    = "TUNNEL_TOKEN"
  value   = local.tunnel_token
}

output "tunnel_id" {
  value     = local.tunnel_id
  sensitive = true
}

output "account_tag" {
  value = local.account_tag
}

# DNS Records - Tunnel CNAMEs
# Tunnel ingress rules are managed via the cloudflared ConfigMap in Kubernetes
# (kubernetes/apps/network/cloudflare-tunnel/config/config.sops.yaml)
resource "cloudflare_record" "tunnel_wildcard" {
  count   = var.doppler_token != "" ? 1 : 0
  zone_id = local.cf_zone_id
  name    = "*"
  type    = "CNAME"
  content = "${cloudflare_tunnel.tunnel.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "Wildcard Tunnel (Managed by Terraform)"
}

resource "cloudflare_record" "tunnel_root" {
  count   = var.doppler_token != "" ? 1 : 0
  zone_id = local.cf_zone_id
  name    = "@"
  type    = "CNAME"
  content = "${cloudflare_tunnel.tunnel.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "Root Tunnel (Managed by Terraform)"
}