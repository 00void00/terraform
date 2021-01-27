provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "project" {

  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true

  tags = {
    Name = "project"
  }
}
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.0.0/25"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private"
  }
}
resource "aws_db_subnet_group" "default" {
  name        = "subnet-group"
  description = "Terraform example RDS subnet group"
  subnet_ids  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project.id

  tags = {
    Name = "Internet Gateway"
  }
}
resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.project.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table."
  }
}

resource "aws_route_table_association" "public_route" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public_route.id
}
resource "aws_instance" "first_instance" {
  ami                         = "ami-0885b1f6bd170450c"
  instance_type               = "t2.micro"
  key_name                    = "project"
  vpc_security_group_ids      = ["${aws_security_group.allow_ssh.id}"]
  subnet_id                   = aws_subnet.subnet1.id
  user_data                   = file("apache.sh")
  associate_public_ip_address = true

  tags = {
    Name = "server1"
  }
}
resource "aws_instance" "sec_instance" {
  ami                         = "ami-0885b1f6bd170450c"
  instance_type               = "t2.micro"
  key_name                    = "project"
  vpc_security_group_ids      = ["${aws_security_group.allow_ssh.id}"]
  subnet_id                   = aws_subnet.subnet1.id
  user_data                   = file("apache2.sh")
  associate_public_ip_address = true

  tags = {
    Name = "server2"
  }
}
resource "aws_instance" "bastion" {
  ami                         = "ami-0be2609ba883822ec"
  key_name                    = "project"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  subnet_id                   = aws_subnet.subnet1.id
  associate_public_ip_address = true

  tags = {
    Name = "bastion-host"
  }
}
resource "aws_db_instance" "RDS" {
  allocated_storage      = 15
  identifier             = "connect"
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "8.0.21"
  instance_class         = "db.t2.micro"
  name                   = "mydb"
  username               = "admin"
  password               = "project123"
  vpc_security_group_ids = ["${aws_security_group.rds-sg.id}"]
  db_subnet_group_name   = aws_db_subnet_group.default.name
}
resource "aws_security_group" "rds-sg" {
  name   = "my-rds-sg"
  vpc_id = aws_vpc.project.id
}

# Ingress Security Port 3306
resource "aws_security_group_rule" "mysql_inbound_access" {
  from_port                = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds-sg.id
  to_port                  = 3306
  type                     = "ingress"
  source_security_group_id = aws_security_group.bastion.id
}
resource "aws_security_group_rule" "mysql_outbound_access" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds-sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group" "bastion" {
  name        = "Bastion host"
  description = "Allow SSH access to bastion host and outbound internet access"
  vpc_id      = aws_vpc.project.id
}
resource "aws_security_group_rule" "ssh" {
  protocol          = "TCP"
  from_port         = 22
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}
resource "aws_security_group_rule" "mysql_access" {
  from_port                = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  to_port                  = 3306
  type                     = "ingress"
  source_security_group_id = aws_security_group.bastion.id
}
resource "aws_security_group_rule" "http_access" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.bastion.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "allow_all" {
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion.id
}
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound connections"
  vpc_id      = aws_vpc.project.id

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
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_lb" "example" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my-alb-sg.id]
  subnets            = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
  ip_address_type    = "ipv4"
}

resource "aws_lb_target_group" "example" {
  name        = "example"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.project.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }
}
resource "aws_lb_target_group_attachment" "attached" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.first_instance.id
  port             = 80
}
resource "aws_lb_target_group_attachment" "attached2" {
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.sec_instance.id
  port             = 80
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.id
  port              = 80
  protocol          = "HTTP"


  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type             = "forward"
  }
}
resource "aws_security_group" "my-alb-sg" {
  name   = "my-alb-sg"
  vpc_id = aws_vpc.project.id
}

resource "aws_security_group_rule" "inbound_ssh" {
  from_port         = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.my-alb-sg.id
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "inbound_http" {
  from_port         = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.my-alb-sg.id
  to_port           = 80
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "outbound_all" {
  from_port         = 0
  protocol          = "-1"
  security_group_id = aws_security_group.my-alb-sg.id
  to_port           = 0
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
}
