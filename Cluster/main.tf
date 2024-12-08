# Specify the AWS provider and region to deploy resources
provider "aws" {
  region = "ap-south-1"
}

# Create a VPC with a CIDR block of 10.0.0.0/16
resource "aws_vpc" "bluegreen_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bluegreen-vpc"
  }
}

# Create two public subnets within the VPC, one in each availability zone
resource "aws_subnet" "bluegreen_subnet" {
  count = 2
  vpc_id                  = aws_vpc.bluegreen_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bluegreen_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "bluegreen-subnet-${count.index}"
  }
}

# Create an internet gateway for the VPC to enable internet connectivity
resource "aws_internet_gateway" "bluegreen_igw" {
  vpc_id = aws_vpc.bluegreen_vpc.id

  tags = {
    Name = "bluegreen-igw"
  }
}

# Create a route table and associate it with the internet gateway for outbound internet access
resource "aws_route_table" "bluegreen_route_table" {
  vpc_id = aws_vpc.bluegreen_vpc.id

  route {
    cidr_block = "0.0.0.0/0" # Default route for all outbound traffic
    gateway_id = aws_internet_gateway.bluegreen_igw.id
  }

  tags = {
    Name = "bluegreen-route-table"
  }
}

# Associate the route table with the public subnets
resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.bluegreen_subnet[count.index].id
  route_table_id = aws_route_table.bluegreen_route_table.id
}

# Create a security group for the EKS cluster, allowing all outbound traffic
resource "aws_security_group" "bluegreen_cluster_sg" {
  vpc_id = aws_vpc.bluegreen_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bluegreen-cluster-sg"
  }
}

# Create a security group for the EKS node group, allowing all inbound and outbound traffic
resource "aws_security_group" "bluegreen_node_sg" {
  vpc_id = aws_vpc.bluegreen_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bluegreen-node-sg"
  }
}

# Create the EKS cluster with the specified VPC, subnets, and security groups
resource "aws_eks_cluster" "bluegreen" {
  name     = "bluegreen-cluster"
  role_arn = aws_iam_role.bluegreen_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.bluegreen_subnet[*].id
    security_group_ids = [aws_security_group.bluegreen_cluster_sg.id]
  }
}

# Define the node group for the EKS cluster
resource "aws_eks_node_group" "bluegreen" {
  cluster_name    = aws_eks_cluster.bluegreen.name
  node_group_name = "bluegreen-node-group"
  node_role_arn   = aws_iam_role.bluegreen_node_group_role.arn
  subnet_ids      = aws_subnet.bluegreen_subnet[*].id

  scaling_config {
    desired_size = 3 # Number of nodes
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.large"] # Instance type for the nodes

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.bluegreen_node_sg.id]
  }
}

# IAM role for the EKS cluster
resource "aws_iam_role" "bluegreen_cluster_role" {
  name = "bluegreen-cluster-role
