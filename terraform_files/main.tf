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

locals {
  vpc_id           = "vpc-065b70841a57add2f"
  subnet_id        = "subnet-060a1ae52cf0a73d6"
  ssh_user         = "ubuntu"
  key_name         = "server_key"
  private_key_path = "/var/lib/jenkins/workspace/jenkins_files/Webserver/1_Deploy_Infrastructure_on_AWS/server_key.pem"
}

resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name = aws_key_pair.server_key.key_name
  security_groups = ["${aws_security_group.allow_tls.name}"]
  tags = {
    Name = var.instance_name
  }
  
  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]

    connection {
      type        = "ssh"
      user        = local.ssh_user
      private_key = file(local.private_key_path)
      host        = aws_instance.nginx.public_ip
    }
  }
  
  provisioner "local-exec" {
    command= "echo ${aws_instance.web.public_ip} >> ../inventory"
  } 
  
  provisioner "local-exec" {
    command = "ansible-playbook  -i ../inventory, --private-key ${local.private_key_path} ../deploy_tomcat.yaml"
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


