# OpenTofu outputs for Talos VM deployment

output "node_ips" {
  description = "Static IP addresses assigned to each node"
  value = {
    for node in var.nodes : node.name => node.address
  }
}
