terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.61.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-2"
}

resource "aws_key_pair" "server_key" {
  key_name   = "server_key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "server_key.pem"
}

resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name = aws_key_pair.server_key.key_name
  security_groups = ["${aws_security_group.allow_tls.name}"]
  tags = {
    Name = var.instance_name
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "server_sg"
  description = "Allow TLS inbound traffic"

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "server_sg"
  }
}

output "server_ip"{
  value=aws_instance.web.network_interface.0.access_config.nat_ip
}

resource "local_file" "hosts_cfg" {
  content  = templatefile("${path.module}/templates/hosts.tpl",
    {
      server_ip = aws_instance.web.network_interface.0.access_config.nat_ip
    }
  filename = "server_key.pem"
}
