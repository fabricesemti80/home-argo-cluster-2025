# OpenTofu version and provider requirements

terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.40"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}
