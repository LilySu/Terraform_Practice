# https://learn.hashicorp.com/tutorials/terraform/packer?in=terraform/provision
# Packer is HashiCorp's open-source tool for creating machine images
# from source configuration. You can configure Packer images with
# an operating system and software for your specific use-case.

# Terraform configuration for a compute instance can use a Packer
# image to provision your instance without manual configuration.

# Packer's configuration will pass it a shell script to run when
# it builds the image.

# The script for this tutorial will update the default software
# on your instance to the latest versions, install necessary
# app software (git, go, etc) and create your user & groups
# so you can SSH into the machine with the username and SSH
# key you created.

# setup.sh script installs the necessary dependencies,
# adds the terraform user to the sudo group, installs the
# previously created SSH key, and downloads the sample
# GoLang webapp.

# Your Packer configuration defines the parameters of
# the image you want to build.

# In SETUP.SH
# variables block. This determines the environment
# variables Packer will use for your AWS account.
# This region must match the region where Terraform
# will deploy your infrastructure

# The builders block creates an AMI named
# learn-packer {{timestamp}} that's based on
# a t2.micro Ubuntu image with Elastic Block Storage
# (EBS).

# he provisioners block builds out your instances
# with specific scripts or files.

# The first provisioner is a file type provisioner and copies
# your newly created public SSH key to a temporary
# directory on the image.
# The second provisioner is a shell type which points
# to the relative path to your bash script. Packer
# uses these provisioners to customize the image
# to your specifications.

provider "aws" {
  region = var.region
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.cidr_subnet
}

resource "aws_route_table" "rtb_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta_subnet_public" {
  subnet_id      = aws_subnet.subnet_public.id
  route_table_id = aws_route_table.rtb_public.id
}

resource "aws_security_group" "sg_22_80" {
  name   = "sg_22"
  vpc_id = aws_vpc.vpc.id

  # SSH access from the VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "web" {
  ami                         = "ami-04c890a61ed62d7c7"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet_public.id
  vpc_security_group_ids      = [aws_security_group.sg_22_80.id]
  associate_public_ip_address = true

  tags = {
    Name = "Learn-Packer"
  }
}

output "id" {
  value = aws_instance.web.public_ip
}