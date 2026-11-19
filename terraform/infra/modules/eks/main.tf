variable "ci_role_arn" { type = string }
variable "local_principal_arn" { type = string }
data "aws_availability_zones" "available" { state = "available" }
locals { name = "training-eks" }
resource "aws_vpc" "lab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = local.name }
}
resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
}
resource "aws_subnet" "worker" {
  count                   = 2
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = cidrsubnet(aws_vpc.lab.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = { Name = "${local.name}-worker-${count.index}", "kubernetes.io/role/elb" = "1" }
}
resource "aws_subnet" "database" {
  count             = 2
  vpc_id            = aws_vpc.lab.id
  cidr_block        = cidrsubnet(aws_vpc.lab.cidr_block, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = { Name = "${local.name}-db-${count.index}" }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
}
resource "aws_route_table_association" "worker" {
  count          = 2
  subnet_id      = aws_subnet.worker[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "database" { vpc_id = aws_vpc.lab.id }
resource "aws_route_table_association" "database" {
  count          = 2
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
resource "aws_iam_role" "cluster" {
  name = "training-eks-control-plane"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_eks_cluster" "lab" {
  name     = local.name
  role_arn = aws_iam_role.cluster.arn
  # AWS chooses its current default supported version. Avoid a stale training pin.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  vpc_config {
    subnet_ids              = aws_subnet.worker[*].id
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"] # IAM-authenticated API; GitHub runners have dynamic IPs.
  }
  depends_on = [aws_iam_role_policy_attachment.cluster, aws_route_table_association.worker]
}
resource "aws_iam_role" "node" {
  name = "training-eks-worker"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly", "AmazonEKS_CNI_Policy"])
  role = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/${each.value}"
}
resource "aws_eks_node_group" "lab" {
  cluster_name    = aws_eks_cluster.lab.name
  node_group_name = "training-workers"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.worker[*].id
  instance_types  = ["t3.medium"]
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  disk_size       = 20
  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }
  depends_on = [aws_iam_role_policy_attachment.node, aws_route_table_association.worker]
}
# Explicit access for the CI role and existing laptop IAM identity.
resource "aws_eks_access_entry" "admin" {
  for_each      = { ci = var.ci_role_arn, local = var.local_principal_arn }
  cluster_name  = aws_eks_cluster.lab.name
  principal_arn = each.value
  type          = "STANDARD"
}
resource "aws_eks_access_policy_association" "admin" {
  for_each      = aws_eks_access_entry.admin
  cluster_name  = aws_eks_cluster.lab.name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
output "cluster_name" { value = aws_eks_cluster.lab.name }
output "cluster_security_id" { value = aws_eks_cluster.lab.vpc_config[0].cluster_security_group_id }
output "vpc_id" { value = aws_vpc.lab.id }
output "db_subnet_ids" { value = aws_subnet.database[*].id }
