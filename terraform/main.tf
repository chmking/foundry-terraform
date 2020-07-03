provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  region  = "us-west-2"
  version = "~> 2.69"
}

terraform {
  backend "s3" {
    bucket = "tf-foundry.coyfox.net"
    key    = "foundry.tfstate"
  }
}

resource "aws_iam_instance_profile" "foundry_instance_profile" {
  name = "foundry_instance_profile"
  role = aws_iam_role.foundry_role.name
}

resource "aws_iam_role" "foundry_role" {
  name = "FoundryVTTRole"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_security_group" "allow_foundry" {
  name        = "allow_foundry"
  description = "Allow Foundry VTT inbound traffic"
  vpc_id      = var.vpc 

  // Allow traffic for the Foundry server
  ingress {
    description = "Foundry VTT Port"
    from_port   = 30000 
    to_port     = 30000 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow SSH access for admin
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22 
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow HTTP access for certbot
  ingress {
    description = "HTTP"
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
    Name = "FoundryVTT"
  }
}

data "aws_ami" "foundry_ami" {
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  most_recent = true
  owners = ["099720109477"]
}

resource "aws_instance" "foundry-server" {
  ami                    = data.aws_ami.foundry_ami.id
  instance_type          = "t2.micro"
  key_name               = var.key_name 
  vpc_security_group_ids = ["${aws_security_group.allow_foundry.id}"]
  iam_instance_profile   = aws_iam_instance_profile.foundry_instance_profile.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "FoundryVTT"
  }
}

resource "aws_s3_bucket" "storage" {
  bucket = var.bucket_name
  acl    = "public-read"

  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "POST", "HEAD"]
    max_age_seconds = 3000
    allowed_headers = ["*"]
  }
}

resource "aws_s3_bucket_policy" "storage_policy" {
  bucket = aws_s3_bucket.storage.id

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "${aws_s3_bucket.storage.arn}/*"
        }
    ]
}
POLICY
}

resource "aws_route53_record" "www" {
  zone_id = var.zone_id 
  name    = var.record_name 
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.foundry-server.public_ip}"]
}

resource "aws_iam_policy" "s3_policy" {
  name = "FoundryS3Access"
  description = "Provides Foundry VTT with s3 bucket access"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:DeleteObject",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "${aws_s3_bucket.storage.arn}/*",
                "${aws_s3_bucket.storage.arn}"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "*"
        }
    ]
}
POLICY
}
