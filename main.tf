terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
}


provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  region                   = "us-east-1"

}


resource "aws_instance" "Jenkins_Server" {
  ami             = "ami-06f8dce63a6b60467" #I found the AMI ID from https://cloud-images.ubuntu.com/locator/ec2/
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.AWSProjectkeypair.key_name
  user_data       = file("Jenkins_installation.sh")
  security_groups = [aws_security_group.Jenkins_Server_Security_Group.name]
  tags = {
    Name = "Jenkins-Server"
  }

}

output "instance_id" {
  value = aws_instance.Jenkins_Server.id
}

data "aws_instance" "Jenkins_Server" {
  instance_id = aws_instance.Jenkins_Server.id
}


resource "aws_cloudfront_distribution" "Jenkins_Server_Distribution" {
  origin {
    domain_name = data.aws_instance.Jenkins_Server.public_dns
    origin_id   = "Jenkins-Server-origin"


    custom_origin_config {
      http_port              = 8080
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  default_root_object = "/jenkins"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "Jenkins-Server-origin"


    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }

}

resource "aws_key_pair" "AWSProjectkeypair" {
  key_name   = "AWSProjectkeypair"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "AWSProjectkeypair" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "awsprojectkeypair"
}


resource "aws_security_group" "Jenkins_Server_Security_Group" {
  name        = "Jenkins_Server_SG"
  description = "This security group is for Jenkins Server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
