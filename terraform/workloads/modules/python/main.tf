# Optional Python deployment, using the existing Flask app and reusable API module.
variable "namespace" { type = string }
variable "image" { type = string }
module "python_api" {
  source    = "../api"
  name      = "python-api"
  namespace = var.namespace
  image     = var.image
  port      = 5000
}
