variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "cluster_security_id" { type = string }
resource "aws_db_subnet_group" "lab" {
  name       = "training-eks-db"
  subnet_ids = var.subnet_ids
}
resource "aws_security_group" "db" {
  name        = "training-eks-db"
  description = "Postgres from EKS nodes only"
  vpc_id      = var.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "postgres" {
  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = var.cluster_security_id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
resource "aws_db_instance" "lab" {
  identifier                  = "training-eks-db"
  engine                      = "postgres"
  instance_class              = "db.t4g.micro"
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "training"
  username                    = "trainingadmin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.lab.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  multi_az                    = false
  backup_retention_period     = 0 # Lab only
  deletion_protection         = false
  skip_final_snapshot         = true # Lab only: demo data is disposable
}
output "address" { value = aws_db_instance.lab.address }
output "secret_arn" { value = aws_db_instance.lab.master_user_secret[0].secret_arn }
