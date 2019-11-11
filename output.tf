output "proddb_db_instance_address" {
  description = "The address of the PRODDB RDS instance"
  value       = "${aws_db_instance.proddb.address}"
}

output "vault_db_instance_address" {
  description = "The address of the VAULT RDS instance"
  value       = "${aws_db_instance.vault.address}"
}

output "connections" {
  value = <<VAULT
Connect to Vault via SSH   ssh -i private.key ubuntu@${aws_instance.vault[0].public_ip}
Vault web interface  http://${aws_instance.vault[0].public_ip}:8200/ui
NGINX web interface  https://${aws_instance.vault[0].public_ip}
VAULT
}