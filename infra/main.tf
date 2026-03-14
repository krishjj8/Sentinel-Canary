
provider "aws" {
  region = "ap-south-1"
}
#Security Group
resource "aws_security_group" "sentinel_sg" {
  name = "sentinel_sg"
  vpc_id = aws_vpc.sentinel_vpc.id
  #SSH
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #HTTP
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #K8s
  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #Allow all
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

data "aws_ami" "ubuntu_noble" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
resource "aws_instance" "sre_node" {
  ami           = data.aws_ami.ubuntu_noble.id
  instance_type = "t3a.medium"


  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sentinel_sg.id]


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
                --disable servicelb \
                --write-kubeconfig-mode 644
              EOF

  tags = {
    Name    = "Sentinel-SRE-Node"
    Stage   = "Stage-1"
  }
}
#ECR
resource "aws_ecr_repository" "sentinel_app" {
  name = "sentinel-app"
  image_tag_mutability = "MUTABLE"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

#OUTPUT
output "node_public_ip" {
  value = aws_instance.sre_node.public_ip
}
output "ecr_repository_url" {
  description = "URL of ECR"
  value = aws_ecr_repository.sentinel_app.repository_url
}