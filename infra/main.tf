provider "aws" {
  region = "ap-south-1"
}

# Security Group
resource "aws_security_group" "sentinel_sg" {
  name   = "sentinel_sg"
  vpc_id = aws_vpc.sentinel_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 32000
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = "Sentinel" }
}

data "aws_ami" "ubuntu_noble" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "sre_node" {
  ami           = data.aws_ami.ubuntu_noble.id
  instance_type = "t3a.medium"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sentinel_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  key_name = "sentinel-key"

  user_data = <<-EOF
              #!/bin/bash
              fallocate -l 4G /swapfile
              chmod 600 /swapfile
              mkswap /swapfile
              swapon /swapfile
              echo '/swapfile none swap sw 0 0' >> /etc/fstab

              curl -sfL https://get.k3s.io | sh -s - server \
                --disable traefik \
                --write-kubeconfig-mode 644
              EOF

  tags = {
    Name    = "Sentinel-SRE-Node"
    Project = "Sentinel"
  }
}

# Elastic IP Resource
resource "aws_eip" "sentinel_eip" {
  instance = aws_instance.sre_node.id
  domain   = "vpc"

  # Ensures the instance is running before attempting EIP association
  depends_on = [aws_instance.sre_node]

  tags = { Name = "Sentinel-Static-IP" }
}

# ECR Repository
resource "aws_ecr_repository" "sentinel_app" {
  name                 = "sentinel-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "sentinel_app_policy" {
  repository = aws_ecr_repository.sentinel_app.name
  policy     = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only last 3 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 3 }
      action       = { type = "expire" }
    }]
  })
}

# OUTPUTS
output "fixed_public_ip" {
  description = "The static Elastic IP address"
  value       = aws_eip.sentinel_eip.public_ip
}

output "ecr_repository_url" {
  description = "URL of ECR"
  value       = aws_ecr_repository.sentinel_app.repository_url
}