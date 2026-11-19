variable "ci_role_arn" {
  type        = string
  description = "Existing main-only GitHub OIDC infrastructure role ARN (not STS session ARN)."
}
variable "local_principal_arn" {
  type        = string
  description = "Existing IAM user/role ARN for laptop; not root or an STS session ARN."
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/.+$", var.local_principal_arn))
    error_message = "Use an IAM user or role ARN, not root or an STS assumed-role ARN."
  }
}
module "eks" {
  source              = "./modules/eks"
  ci_role_arn         = var.ci_role_arn
  local_principal_arn = var.local_principal_arn
}
module "database" {
  source               = "./modules/database"
  vpc_id               = module.eks.vpc_id
  subnet_ids           = module.eks.db_subnet_ids
  cluster_security_id  = module.eks.cluster_security_id
}
# Java ECR already exists from the previous training session. Never delete it.
data "aws_ecr_repository" "java" {
  name = "training/java-api"
}
resource "aws_ecr_repository" "new" {
  for_each             = toset(["node", "python"])
  name                 = "training/eks-${each.key}-api"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # Lab only: destroy removes these two demo repos and their images.
  image_scanning_configuration { scan_on_push = true }
}
output "cluster_name" { value = module.eks.cluster_name }
output "db_host" { value = module.database.address }
output "db_secret_arn" {
  value     = module.database.secret_arn
  sensitive = true
}
output "java_repository" { value = data.aws_ecr_repository.java.repository_url }
output "node_repository" { value = aws_ecr_repository.new["node"].repository_url }
output "python_repository" { value = aws_ecr_repository.new["python"].repository_url }
