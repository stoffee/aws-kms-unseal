resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "11.5"
  instance_class       = "db.t2.micro"
  name                 = "proddb"
  username             = "stoffee"
  password             = "!4me2know!"
  publicly_accessible  = true
  skip_final_snapshot  = true
}