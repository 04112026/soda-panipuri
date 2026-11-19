terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
  backend "s3" {
    region       = "eu-north-1"
    key          = "training-eks/workloads.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
# aws eks update-kubeconfig is executed before terraform apply/destroy.
provider "kubernetes" { config_path = "~/.kube/config" }
variable "java_image" { type = string }
variable "node_image" { type = string }
variable "python_image" { type = string }
variable "enable_python" {
  type    = bool
  default = false
}
locals { namespace = "training" }
# Namespace and DB Secret are created safely by scripts/deploy.sh (not stored in TF state).
module "java" {
  source    = "./modules/api"
  name      = "java-api"
  namespace = local.namespace
  image     = var.java_image
  port      = 8080
  database  = true
}
module "node" {
  source    = "./modules/api"
  name      = "node-api"
  namespace = local.namespace
  image     = var.node_image
  port      = 3000
  database  = true
}
module "python" {
  count     = var.enable_python ? 1 : 0
  source    = "./modules/python"
  namespace = local.namespace
  image     = var.python_image
}
