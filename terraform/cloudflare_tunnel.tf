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

variable "credentials_file" {
  description = "Path to existing credentials file"
  type        = string
  default     = "./../cloudflare-tunnel.json"
}

variable "doppler_token" {
  description = "Doppler token"
  type        = string
  sensitive   = true
  default     = ""
}

provider "cloudflare" {
  api_token = var.cf_api_token
}

provider "doppler" {
  doppler_token = var.doppler_token
}

data "cloudflare_zero_trust_tunnel_cloudflared" "existing" {
  account_id = var.cf_account_id
  name       = var.tunnel_name
}

locals {
  tunnel_id     = data.cloudflare_zero_trust_tunnel_cloudflared.existing.id
  account_tag   = var.cf_account_id
  tunnel_secret = var.tunnel_secret != "" ? var.tunnel_secret : jsondecode(file(var.credentials_file)).TunnelSecret
  tunnel_name   = var.tunnel_name

  credentials_json = jsonencode({
    AccountTag   = local.account_tag
    TunnelID     = local.tunnel_id
    TunnelSecret = local.tunnel_secret
    TunnelName   = local.tunnel_name
  })
}

resource "local_file" "credentials" {
  content  = local.credentials_json
  filename = pathexpand("${path.module}/../cloudflare-tunnel.json")
}

resource "doppler_secret" "tunnel_credentials" {
  config     = "dev"
  project    = "home-argo-cluster-2025"
  name       = "TUNNEL_CREDENTIALS"
  value      = local.credentials_json
  value_type = "json"
}

resource "doppler_secret" "tunnel_id" {
  config  = "dev"
  project = "home-argo-cluster-2025"
  name    = "TUNNEL_ID"
  value   = local.tunnel_id
}

output "tunnel_id" {
  value     = local.tunnel_id
  sensitive = true
}

output "account_tag" {
  value = local.account_tag
}