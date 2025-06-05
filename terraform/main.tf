terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
  access_key="ASIA22VHHBYY2N63T4IB"  
  secret_key="0MveyZdGWIUNsk2tNj+nHIrIf1A33+q4KtQQ0+F0"
  token="IQoJb3JpZ2luX2VjEGkaCXVzLXdlc3QtMiJGMEQCIEIhYv1LomdblWY2oYYtj05t95Tfl2r0LHtDoBN4+rlEAiBvBZwbnKD0wshLra41lul4BfB4c5GS4UwsTNOQsZnuOyqgAghCEAAaDDc0NDQ1Mzc3MDgwMSIM08jRAE7D3i5m1YX+Kv0Biy3gMYch93g4Y6AzU7Paw6te2wMnRruTZfONy5wz+2HGZ2hPCWdR7KCaA1XGsCy2+Icu3MwEBaBjy4PGccGXieZyNXyY+Rtc0T7QDsEmsCO6aUMUn6dmPIw0mSwjEQCro0JKiL5aKN7T9P/t/wulPjdKxBRVpekmWVRJCIYt78NEbJr0yJXysV62vSI8/TosmabNheEvsjBwMd7MBbeTttwaw4CIIKT26NE3+4hts+3Ah81PoHOfGdUIqNlDijDxgFQX7D4leYY/f9Opz6Y/ZMTMIFSK/qScd5XzYS2wZkNQAjQlPNfesHMnNYssiI21GO/3kM7OavDQWO7VJjDswIXCBjqeAeZ3h1wuPafZW1SkAmhRp+/vnwceLegJL7uYW3VikLWnm+/ZOzss9LSqYciJcwafcrTUKl5Dc2iLwo50GM/d84zngRTrEy3nGQqJefmP714smcJ0P8ndBHeqlzZLi6NHvn0qvW7QgQ7agexNdhYaVFpPpHbxkxs3raR1ZehBTho8bpgSUFMI4pID9NU6RBZACZKw8TdBB+5mLq3Ydcp+"
}

# Generate SSH key pair
resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key in SSM Parameter Store
resource "aws_ssm_parameter" "private_key" {
  name        = "/ssh/demo-keypair/private"
  description = "Private SSH key for EC2 demo"
  type        = "SecureString"
  value       = tls_private_key.demo_key.private_key_pem

  tags = {
    environment = "demo"
  }
}

# Create AWS key pair using the public key
resource "aws_key_pair" "demo_keypair" {
  key_name   = "demo-keypair"
  public_key = tls_private_key.demo_key.public_key_openssh
}

# Create VPC
resource "aws_vpc" "demo_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "demo-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = {
    Name = "demo-igw"
  }
}

# Route Table
resource "aws_route_table" "demo_rt" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = {
    Name = "demo-rt"
  }
}

# Subnet
resource "aws_subnet" "demo_subnet" {
  vpc_id                  = aws_vpc.demo_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "demo-subnet"
  }
}

# Route Table Association
resource "aws_route_table_association" "demo_rta" {
  subnet_id      = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.demo_rt.id
}

# Security Group
resource "aws_security_group" "demo_sg" {
  name        = "demo-sg"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.demo_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
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

  tags = {
    Name = "demo-sg"
  }
}

# EC2 Instance
resource "aws_instance" "demo_instance" {
  ami                    = "ami-0779caf41f9ba54f0" // Replace with a valid AMI ID for your region
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.demo_subnet.id
  key_name               = aws_key_pair.demo_keypair.key_name
  vpc_security_group_ids = [aws_security_group.demo_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y python3 python3-pip python3-venv
  EOF

  tags = {
    Name = "demo-instance"
  }
}

# Outputs
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.demo_instance.public_ip
}
