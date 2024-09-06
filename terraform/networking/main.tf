/* 
This module includes: 
    VPC: Virtual Private Cloud
    Private Subnets in 2 AZs
    Public Subnets in 1 AZ
    Route Table: Rule the traffic that goes to public subnet
    Internet Gateway: Allow internet access
    Security Groups
Notes: 
  - The VPC exists across all the AZs in a region while subnets are associated with a single AZ.
  - For CIDR: 32-[16] = 16 => 2^16 times IP allocation. See https://cidr.xyz/
  - Region of "eu-central-1" has 3 AZs; a,b,c
*/
# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "VoiceCloning VPC"
  }
}

# Public Subnet
resource "aws_subnet" "public_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"
  
  tags = {
    Name = "VoiceCloning public-subnet-1a"
  }
}

# 2 Private subnets in two AZs
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}a"
  
  tags = {
    Name = "VoiceCloning private-subnet-1a"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.region}b"
  
  tags = {
    Name = "VoiceCloning private-subnet-1b"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "VoiceCloning IGW"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "VoiceCloning Public Route Table"
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "batch" {
  name        = "security_group-batch-for-voicecloning"
  vpc_id      = aws_vpc.main.id
  description = "Security group for AWS Batch"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "VoiceCloning Batch SG"
  }
}
