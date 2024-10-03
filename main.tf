provider "aws" {
  region = "us-east-1" 
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = file("../.ssh/sshkey.pub") 
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "main-internet-gateway"
  }
}

resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0" 
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.default.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "default" {
  vpc_id            = aws_vpc.default.id 
  cidr_block        = "10.0.1.0/24" 
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "instance_sg" {
  name   = "SG-instance-kind"
  vpc_id = aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
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


resource "aws_instance" "ec2_instance" {
  ami             = "ami-0ebfd941bbafe70c6" # Amazon Linux 2
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  subnet_id              = aws_subnet.default.id 
  associate_public_ip_address = true 

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              
              # Install docker
              sudo amazon-linux-extras install docker -y
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -a -G docker ec2-user

              # Install kubectl
              curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/amd64/kubectl
              chmod +x ./kubectl
              sudo mv ./kubectl /usr/local/bin/kubectl

              # Install Kind
              curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
              chmod +x ./kind
              sudo mv ./kind /usr/local/bin/kind

              # Create kind cluster
              kind create cluster
            EOF

  tags = {
    Name = "magoya-kind-cluster"
  }
}
