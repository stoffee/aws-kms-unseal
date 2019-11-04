variable "aws_region" {
  default = "us-west-1"
}

variable "aws_zone" {
  default = "us-west-1c"
}

variable "aws_zone-2" {
  default = "us-west-1b"
}

variable "vault_url" {
  default = "https://releases.hashicorp.com/vault/1.2.3/vault_1.2.3_linux_amd64.zip"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC"
  default     = "192.168.100.0/24"
}

# removing for postgres branch
#variable "postgres_cidr" {
#  type        = string
#  description = "CIDR of the VPC"
#  default     = "10.0.1.0/24"
#}

variable "db_address" {
  description = "address of the DB server"
  default = "aws_db_instance_default.address"
}

variable "namespace" {
  description = "Prepended name of all resources"
  default = "aws-vault"
}