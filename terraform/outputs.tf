# OpenTofu outputs for Talos VM deployment

output "nodes" {
  description = "Details of all provisioned nodes with current DHCP status"
  value       = module.talos.nodes
}

output "control_plane_nodes" {
  description = "Control plane node details with DHCP IPs"
  value       = module.talos.control_plane_nodes
}

output "worker_nodes" {
  description = "Worker node details with DHCP IPs"
  value       = module.talos.worker_nodes
}

output "vm_dhcp_ipv4_addresses" {
  description = "Current DHCP-assigned IPv4 addresses for all VMs (may be empty if VMs are still booting)"
  value       = module.talos.vm_dhcp_ipv4_addresses
}

output "ready_nodes_with_ips" {
  description = "Nodes that have successfully obtained DHCP addresses (ready for Talos configuration)"
  value       = module.talos.ready_nodes_with_ips
}

output "cluster_node_ips_summary" {
  description = "Summary of node DHCP IPs for cluster configuration (empty if VMs still booting)"
  value       = module.talos.cluster_node_ips_summary
}

output "vm_network_details" {
  description = "Detailed network information for debugging DHCP assignment"
  value       = module.talos.vm_network_details
}

output "next_steps_for_cluster_config" {
  description = "Instructions for getting DHCP IPs after VMs have booted"
  value       = module.talos.next_steps_for_cluster_config
}
