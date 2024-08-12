terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_instance" "bamboo-server" {
  ami           = "ami-0ae8f15ae66fe8cda"
  instance_type = "t2.xlarge"

  user_data = <<-EOF
                #!/bin/bash
                sudo yum install -y docker
                sudo systemctl start docker
                sudo usermod -aG docker $USER
                newgrp docker
                docker volume create --name bambooVolume
                docker volume create --name bambooAgentVolume
                docker volume create --name postgresVolume
                docker run \
                  -v bambooVolume:/var/atlassian/application-data/bamboo \
                  --name="bamboo" -d \
                  -p 80:8085 \
                  -p 54663:54663 \
                  atlassian/bamboo
                docker run \
                  --name postgres \
                  -e POSTGRES_PASSWORD=admin \
                  -e POSTGRES_USER=admin \
                  -e POSTGRES_DB=bamboo \
                  -e PGDATA=/var/lib/postgresql/data/pgdata \
                  -e postgresVolume:/var/lib/postgresql/data \
                  -p 5432:5432 \
                  -d postgres:16
                EOF

  tags = {
    Name = "bamboo-server"
  }

  key_name = aws_key_pair.bamboo-server-ssh.key_name

  vpc_security_group_ids = [
    aws_security_group.bamboo-server-sg.id
  ]
}

# ssh-keygen -t rsa -b 2048 -f "bamboo-server.key"
resource "aws_key_pair" "bamboo-server-ssh" {
  key_name   = "bamboo-server-ssh"
  public_key = file("bamboo-server.key.pub")
}

resource "aws_security_group" "bamboo-server-sg" {
  name        = "bamboo-server-sg"
  description = "Security group allowing SSH and HTTP access"

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
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}