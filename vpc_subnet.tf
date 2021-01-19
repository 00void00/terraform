provider "aws" {
    region = "us-east-1"
}
resource "aws_vpc" "project" {

    cidr_block       = "10.0.0.0/24"
       
    tags = {
        Name = "project"
  }
}
resource "aws_subnet" "subent1" {
    vpc_id     = aws_vpc.project.id
    cidr_block = "10.0.0.0/25"
    
    tags = {
        Name = "public"
  }
}
resource "aws_subnet" "subent2" {
    vpc_id     = aws_vpc.project.id
    cidr_block = "10.0.0.0/25"
    
    tags = {
        Name = "private"
  }
}
