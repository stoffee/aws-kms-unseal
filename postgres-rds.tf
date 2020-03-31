resource "aws_db_instance" "proddb" {
  allocated_storage   = 20
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "11.5"
  instance_class      = "db.t2.micro"
  name                = "proddb"
  username            = var.proddb_username
  password            = var.proddb_password
  publicly_accessible = true
  skip_final_snapshot = true
  tags = {
    Owner = "cdunlap"
    TTL   = "96"
  }
}

resource "aws_db_instance" "vault" {
  allocated_storage   = 20
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "11.5"
  instance_class      = "db.t2.micro"
  name                = "vault"
  username            = var.vaultdb_username
  password            = var.vaultdb_password
  publicly_accessible = true
  skip_final_snapshot = true
  tags = {
    Owner = "cdunlap"
    TTL   = "96"
  }
}