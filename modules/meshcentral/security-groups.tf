#security-groups.tf
resource "aws_security_group" "http_access_sg" {
  count = "${var.ec2_instance_count}"
  name = "${replace(var.ec2_config.fqdn, ".", "-")}-remote-wan-ip-sg"
  vpc_id      = data.aws_vpc.vpc.id
  description = "Unrestricted Ports and IPs - Managed by Terraform"
  lifecycle {
    create_before_destroy = true
  } 
  ingress {
    description = "Whitelist Admin IP"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.my_ip_cidr]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Intel AMT"
    from_port   = 4433
    to_port     = 4433
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Intel AMT"
    from_port   = 4433
    to_port     = 4433
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "all-vpcs-sg" {
  count = "${var.ec2_instance_count}"
  name = "${var.ec2_config.fqdn}-tf-all-vpcs-sg"
  vpc_id      = data.aws_vpc.vpc.id
  description = "All traffic allowed to all VPCs and peered VPCs - Managed by Terraform"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }
    egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "http" "my_ip" {
  url = "https://api.ipify.org"
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}