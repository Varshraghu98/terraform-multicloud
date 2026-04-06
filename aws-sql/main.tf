terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name for SSH access (optional)."
  type        = string
  default     = null
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "aws_application_deployment_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "aws-application-deployment-vpc"
  }
}

resource "aws_internet_gateway" "aws_application_deployment_igw" {
  vpc_id = aws_vpc.aws_application_deployment_vpc.id

  tags = {
    Name = "aws-application-deployment-igw"
  }
}

resource "aws_subnet" "aws_application_deployment_subnet_public1_eu_central_1a" {
  vpc_id                  = aws_vpc.aws_application_deployment_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "aws-application-deployment-subnet-public1-eu-central-1a"
  }
}

resource "aws_route_table" "aws_application_deployment_rtb_public" {
  vpc_id = aws_vpc.aws_application_deployment_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_application_deployment_igw.id
  }

  tags = {
    Name = "aws-application-deployment-rtb-public"
  }
}

resource "aws_route_table_association" "aws_application_deployment_rtb_assoc_public1_eu_central_1a" {
  subnet_id      = aws_subnet.aws_application_deployment_subnet_public1_eu_central_1a.id
  route_table_id = aws_route_table.aws_application_deployment_rtb_public.id
}

resource "aws_vpc_endpoint" "aws_application_deployment_vpce_s3" {
  vpc_id            = aws_vpc.aws_application_deployment_vpc.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.aws_application_deployment_rtb_public.id]

  tags = {
    Name = "aws-application-deployment-vpce-s3"
  }
}

resource "aws_security_group" "aws_application_deployment_ec2_flask_sg" {
  name        = "aws-application-deployment-ec2-flask-sg"
  description = "Allow SSH and web for EC2 Flask instance"
  vpc_id      = aws_vpc.aws_application_deployment_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask default port"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MySQL default port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "aws-application-deployment-ec2-flask-sg"
  }
}

resource "aws_instance" "aws_application_deployment_ec2_flask" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.aws_application_deployment_subnet_public1_eu_central_1a.id
  vpc_security_group_ids      = [aws_security_group.aws_application_deployment_ec2_flask_sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name

  tags = {
    Name = "aws-application-deployment-ec2-flask"
  }
}
