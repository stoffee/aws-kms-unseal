# Vault Auto-unseal using AWS KMS and RDS MYSQL database permissions & Vault Ca backed SSH

This repo contains a file storage based Vault single server in AWS.
            ** THIS IS NOT FOR PRODUCTION **
* Deply Vault with Auto Uneal 
* * https://www.vaultproject.io/docs/concepts/seal/
* Deploy Vault Database Secrets Engine to manage Postgres RDS instances
* * https://www.vaultproject.io/docs/secrets/databases/postgresql/
* Database Root Credential Password Rotation with Vault
* * https://learn.hashicorp.com/vault/secrets-management/db-root-rotation

---

## Demo Steps

### Setup

1. Set this location as your working directory
1. Set your AWS credentials as environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
1. Set Vault Enterprise URL in a file named `terraform.tfvars` (see `terraform.tfvars.example`)

### Deployment Commands Cheat Sheet

```bash
# Pull necessary plugins
$ terraform init

$ terraform plan

# Output provides the SSH instruction
$ terraform apply

# Look in the output for the vault server ssh info
# Connect to the vault, ssh, and bastion servers
$ ssh -i private.key ubuntu@<IP_ADDRESS>

#----------------------------------
# Once logged in to any instance
$ vault status

# Check out the vault credentials and unseal key on the Vault server
$ cat /opt/vault/setup/vault.unseal.info

# Login on any server with the root token from above
$ vault login <INITIAL_ROOT_TOKEN>
```
### Demo Cheat Sheet
#
#-----------------------------------
#
NGINX Certs Demo
 Run the scipt `/opt/vault/nginx_demo.sh`

#
#----------------------------------
#
Postgres Demo<br>
$ `vault login <INITIAL_ROOT_TOKEN>`<br>
$ `vault read database/creds/admin-role`<br>
$ `psql -h terraform-20191107214742817000000001.caotp6j0pjol.us-west-1.rds.amazonaws.com -d proddb -U`<br>
```sql
USERNAME -W
SELECT u.usename AS "Role name",
  CASE WHEN u.usesuper AND u.usecreatedb THEN CAST('superuser, create
database' AS pg_catalog.text)
       WHEN u.usesuper THEN CAST('superuser' AS pg_catalog.text)
       WHEN u.usecreatedb THEN CAST('create database' AS
pg_catalog.text)
       ELSE CAST('' AS pg_catalog.text)
  END AS "Attributes"
FROM pg_catalog.pg_user u
ORDER BY 1;
```

#----------------------------------

# Clean up...
$ `terraform destroy -force`<br>
$ `rm -rf .terraform terraform.tfstate*`
