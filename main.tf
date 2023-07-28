provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "myapp_vpc" {

    cidr_block = var.vpc_cidr_block
    
    tags = {
        Name = "${var.env_prefix}-vpc"
    }

}

resource "aws_subnet" "myapp-subnet" {
    
    vpc_id = aws_vpc.myapp_vpc.id

    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    
    tags = {
        Name = "${var.env_prefix}-subnet"
    }
}

resource "aws_internet_gateway" "myapp_igw" {
  vpc_id = aws_vpc.myapp_vpc.id

  tags = {
    Name = "${var.env_prefix}-IGW"
  }
}

resource "aws_default_route_table" "myapp_default_rt" {

  default_route_table_id = aws_vpc.myapp_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp_igw.id
  }

  tags = {
    Name = "${var.env_prefix}-default-gateway"
  }
}

resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.myapp_vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env_prefix}-default-sg"
    }
}

resource "aws_key_pair" "my-ec2-key" {
  key_name   = "server_key"
  public_key = file(var.public_key_location)
}


data "aws_ami" "latest-amazon-linux-image" {
  
  most_recent = true
  
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

}

output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-linux-image.id
}


resource "aws_instance" "myapp-server" {

    ami           = data.aws_ami.latest-amazon-linux-image.id
    instance_type = "t2.micro"

    subnet_id = aws_subnet.myapp-subnet.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    key_name = aws_key_pair.my-ec2-key.key_name

    user_data = file("entry-script.sh")


    tags = {
        Name = "${var.env_prefix}-webserver"
    }
}

output "ec2_public_ip" {
    value = aws_instance.myapp-server.public_ip
}

