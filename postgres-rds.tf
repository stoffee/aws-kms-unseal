resource "aws_db_instance" "proddb" {
  allocated_storage   = 20
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "11.5"
  instance_class      = "db.t2.micro"
  name                = "proddb"
  username            = "dbaccount"
  password            = "4me2know"
  publicly_accessible = true
  skip_final_snapshot = true
  tags = {
    Owner = "cdunlap"
    TTL   = "36hrs"
  }
}

resource "aws_db_instance" "vault" {
  allocated_storage   = 20
  storage_type        = "gp2"
  engine              = "postgres"
  engine_version      = "11.5"
  instance_class      = "db.t2.micro"
  name                = "vault"
  username            = "vaultdbadmin"
  password            = "4me2know"
  publicly_accessible = true
  skip_final_snapshot = true
  tags = {
    Owner = "cdunlap"
    TTL   = "36hrs"
  }
}