output "transaction_executor_dns" {
  value = "${module.transaction_executor.transaction_executor_dns}"
}

output "vault_server_ips" {
  value = "${module.tx_executor_vault.vault_server_public_ips}"
}

output "eximchain_node_lb_dns" {
  value = "${module.eximchain_node.eximchain_node_dns}"
}

output "eximchain_node_direct_dns" {
  value = "${module.eximchain_node.eximchain_node_ssh_dns}"
}
