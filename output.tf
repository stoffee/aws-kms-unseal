output "this_db_instance_address" {
  description = "The address of the RDS instance"
  value       = "${aws_db_instance.default.address}"
}

output "connections" {
  value = <<VAULT
Connect to Vault via SSH   ssh ubuntu@${aws_instance.vault[0].public_ip} -i private.key
Vault web interface  http://${aws_instance.vault[0].public_ip}:8200/ui
VAULT

}

locals {
  vault_db_instance_address           = element(concat(aws_db_instance.default.*.address, aws_db_instance.default.*.address, [""]), 0)
}

output "vault_db_instance_address" {
  description = "The address of the RDS instance"
  value       = local.vault_db_instance_address
}
