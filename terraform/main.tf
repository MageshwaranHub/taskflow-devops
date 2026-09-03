terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# -------------------------
# VPC
# -------------------------

resource "aws_vpc" "taskflow_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "taskflow-vpc"
    Project = "TaskFlow"
  }
}

# -------------------------
# Internet Gateway
# -------------------------

resource "aws_internet_gateway" "taskflow_igw" {
  vpc_id = aws_vpc.taskflow_vpc.id

  tags = {
    Name    = "taskflow-igw"
    Project = "TaskFlow"
  }
}

# -------------------------
# Public Subnet
# -------------------------

resource "aws_subnet" "taskflow_public_subnet" {
  vpc_id                  = aws_vpc.taskflow_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name    = "taskflow-public-subnet"
    Project = "TaskFlow"
  }
}

# -------------------------
# Route Table
# -------------------------

resource "aws_route_table" "taskflow_public_rt" {
  vpc_id = aws_vpc.taskflow_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.taskflow_igw.id
  }

  tags = {
    Name    = "taskflow-public-route-table"
    Project = "TaskFlow"
  }
}

resource "aws_route_table_association" "taskflow_public_rta" {
  subnet_id      = aws_subnet.taskflow_public_subnet.id
  route_table_id = aws_route_table.taskflow_public_rt.id
}

# -------------------------
# Security Group
# -------------------------

resource "aws_security_group" "taskflow_sg" {
  name        = "taskflow-sg"
  description = "Security group for TaskFlow Kubernetes server"
  vpc_id      = aws_vpc.taskflow_vpc.id

  # SSH - restricted to current public IP
  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["157.51.126.33/32"]
  }

  # HTTP - public TaskFlow application
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "taskflow-sg"
    Project = "TaskFlow"
  }
}

# -------------------------
# Latest Ubuntu AMI
# -------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# -------------------------
# AWS Key Pair
# -------------------------

resource "aws_key_pair" "taskflow_key" {
  key_name   = "taskflow-key"
  public_key = file("~/.ssh/taskflow-key.pub")

  tags = {
    Name    = "taskflow-key"
    Project = "TaskFlow"
  }
}

# -------------------------
# EC2 Instance
# -------------------------

resource "aws_instance" "taskflow_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  iam_instance_profile        = aws_iam_instance_profile.taskflow_ec2_profile.name
  user_data_replace_on_change = true

  subnet_id                   = aws_subnet.taskflow_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.taskflow_sg.id]
  associate_public_ip_address = true

  key_name = aws_key_pair.taskflow_key.key_name

  user_data = <<-EOF
              #!/bin/bash
              set -eux

              # Update packages
              apt-get update -y

              # Install required packages
              apt-get install -y docker.io curl git

              # Start Docker
              systemctl enable docker
              systemctl start docker

              # Allow ubuntu user to use Docker
              usermod -aG docker ubuntu

              # Create 2 GB swap to help k3s on a small instance
              if [ ! -f /swapfile ]; then
                fallocate -l 2G /swapfile
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              # Install k3s
              curl -sfL https://get.k3s.io | sh -

              # Configure kubectl for ubuntu user
              mkdir -p /home/ubuntu/.kube
              cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
              chown -R ubuntu:ubuntu /home/ubuntu/.kube

              # Install useful tools
              apt-get install -y git curl

              # Record successful bootstrap
              echo "TaskFlow EC2 bootstrap completed successfully" > /home/ubuntu/bootstrap-complete.txt
              EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "taskflow-server"
    Project = "TaskFlow"
  }
}

# -------------------------
# Elastic IP
# -------------------------

resource "aws_eip" "taskflow_eip" {
  domain = "vpc"

  tags = {
    Name = "taskflow-eip"
  }
}

resource "aws_eip_association" "taskflow_eip_association" {
  instance_id   = aws_instance.taskflow_server.id
  allocation_id = aws_eip.taskflow_eip.id
}

# -------------------------
# Outputs
# -------------------------

output "taskflow_elastic_ip" {
  description = "Elastic IP address of the TaskFlow server"
  value       = aws_eip.taskflow_eip.public_ip
}

output "taskflow_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.taskflow_server.id
}

# -------------------------
# IAM Role for EC2
# -------------------------

resource "aws_iam_role" "taskflow_ec2_role" {
  name = "taskflow-ec2-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "taskflow-ec2-ecr-role"
    Project = "TaskFlow"
  }
}

resource "aws_iam_role_policy_attachment" "taskflow_ecr_readonly" {
  role       = aws_iam_role.taskflow_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "taskflow_ec2_profile" {
  name = "taskflow-ec2-instance-profile"
  role = aws_iam_role.taskflow_ec2_role.name
}
