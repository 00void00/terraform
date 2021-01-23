provider "aws" {
    region = "us-east-1"
}
resource "aws_vpc" "project1" {

    cidr_block = "10.0.0.0/24"
    enable_dns_hostnames = true

    tags = {
        Name = "project"
  }
}
// public subnet configuration
resource "aws_subnet" "subnet1" {
    vpc_id     = aws_vpc.project1.id
    cidr_block = "10.0.0.0/25"
    availability_zone = "us-east-1a"
    
    tags = {
        Name = "public"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project1.id

  tags = {
    Name = "Internet Gateway"
  }
}
resource "aws_route_table" "public_route" {
    vpc_id = aws_vpc.project1.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "Public Route Table."
    }
}

resource "aws_route_table_association" "public_route" {
    subnet_id = aws_subnet.subnet1.id
    route_table_id = aws_route_table.public_route.id
}
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound connections"
  vpc_id = "${aws_vpc.project1.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}
resource "aws_instance" "my_instance" {
  ami = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  key_name = "harsh"
  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}"]
  subnet_id = aws_subnet.subnet1.id
  associate_public_ip_address = true

  tags = {
    Name = "webserver"
  }
}
//--------------------public subnet with ec2 (SG) launched---------------------------------

// private subnet configuration

resource "aws_subnet" "subnet2" {
    vpc_id     = aws_vpc.project1.id
    cidr_block = "10.0.0.128/25"
    availability_zone = "us-east-1b"
    
    tags = {
        Name = "private"
  }
}

resource "aws_db_subnet_group" "default" {
  description = "Terraform example RDS subnet group"
  subnet_ids  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

resource "aws_security_group" "rds" {
  name        = "terraform_rds_security_group"
  description = "Terraform example RDS MySQL server"
  vpc_id      = aws_vpc.project1.id
  # Keep the instance private by only allowing traffic from the web server.
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_ssh.id]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    security_groups = [aws_security_group.bastion-sg.id]
  }
  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "terraform-example-rds-security-group"
  }
}

resource "aws_db_instance" "RDS" {
  allocated_storage    = 5
  identifier = "demo"
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0.21"
  instance_class       = "db.t2.micro"
  name                 = "mydb"
  username             = "demo"
  password             = "project123"
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name = aws_db_subnet_group.default.id
}
//--------------------private subnet with DB (SG) launched---------------------------------

resource "aws_instance" "bastion" {
  ami = "ami-0885b1f6bd170450c"
  key_name                    = "harsh"
  instance_type               = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.bastion-sg.id}"]
  subnet_id = aws_subnet.subnet1.id
  associate_public_ip_address = true
}

resource "aws_security_group" "bastion-sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.project1.id

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    security_groups = [aws_security_group.allow_ssh.id]
  }

  egress {
    protocol    = -1
    from_port   = 0 
    to_port     = 0 
    cidr_blocks = ["0.0.0.0/0"]
  }
}
