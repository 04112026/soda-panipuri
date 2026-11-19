terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes" }
  }
}
variable "name" { type = string }
variable "namespace" { type = string }
variable "image" { type = string }
variable "port" { type = number }
variable "database" {
  type    = bool
  default = false
}
resource "kubernetes_deployment_v1" "api" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = { app = var.name }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = var.name } }
    template {
      metadata { labels = { app = var.name } }
      spec {
        automount_service_account_token = false
        container {
          name  = var.name
          image = var.image
          image_pull_policy = "IfNotPresent"
          port { container_port = var.port }
          dynamic "env_from" {
            for_each = var.database ? [1] : []
            content {
              secret_ref { name = "training-db" }
            }
          }
          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }
          readiness_probe {
            http_get {
              path = var.database ? "/health" : "/"
              port = var.port
            }
            initial_delay_seconds = 3
            period_seconds        = 5
          }
        }
      }
    }
  }
  wait_for_rollout = true
  timeouts { create = "10m" }
}
resource "kubernetes_service_v1" "api" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }
  spec {
    selector = { app = var.name }
    type     = "ClusterIP"
    port {
      port        = var.port
      target_port = var.port
    }
  }
}
