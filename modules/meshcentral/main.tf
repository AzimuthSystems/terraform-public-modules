terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
}

###  Configure EC2 details as necessary.
resource "aws_iam_role" "ec2_role" {
  name = "${var.ec2_config.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# Attach additional inline policy to allow S3 access if backup bucket is enabled
resource "aws_iam_role_policy" "s3_backup_policy" {
  count = var.enable_s3_backup ? 1 : 0
  name  = "${var.ec2_config.name}-s3-backup-access"
  role  = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        aws_s3_bucket.backup_bucket.arn,
        "${aws_s3_bucket.backup_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.ec2_config.name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "ec2" {
  ami                     = data.aws_ami.amazon.id
  key_name		            = var.ec2_config.key_name
  count                   = var.ec2_instance_count
  instance_type           = var.ec2_config.instance_type
  iam_instance_profile    = var.ec2_config.instance_profile_override != null ? var.ec2_config.instance_profile_override : aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids  = [aws_security_group.all-vpcs-sg[count.index].id,aws_security_group.http_access_sg[count.index].id]
  subnet_id               = random_shuffle.public_subnets.result[0]
  source_dest_check       = false
  dynamic "root_block_device" {
    for_each = [(
      var.ec2_config.root_block_device != null
      ? var.ec2_config.root_block_device
      : {
          volume_type = "gp3"
          volume_size = 20
          iops        = 3000
          throughput  = 125
        }
    )]

  content {
    volume_type = root_block_device.value.volume_type
    volume_size = root_block_device.value.volume_size
    iops        = root_block_device.value.volume_iops
    throughput  = root_block_device.value.volume_throughput
    tags = {
      BackupSchedule = "Daily"
      Description    = "MeshCentral Root Volume"
      SystemsManager = "Enabled"
      Name           = "meshcentral /dev/sda1"
      }
    }
  }
  lifecycle {
    ignore_changes = [subnet_id,ami,user_data]
  }

  ### Retrieve launch customizations ###
  user_data = templatefile("${path.module}/cloud_init.tftpl", {
    HOST_NAME               = "${var.ec2_config.fqdn}",
    TIMEZONE                = "${var.ec2_config.timezone}",
    ADMIN_USER              = "${var.mesh_config.admin_user}",
    ADMIN_PASSWORD          = "${var.mesh_config.admin_pass}",
    ADMIN_EMAIL             = "${var.mesh_config.admin_email}",
    MESHCONFIG_SSM_PATH     = aws_ssm_parameter.meshcentral_config.name,
    SWAP_SIZE               = var.ec2_config.swap_size, # Size in GB
    cognito_auth            = var.cognito_config.cognito_auth,
    cognito_admin_oidc      = var.cognito_config.cognito_admin_oidc,
    cognito_admin_full_name = var.cognito_config.cognito_admin_full_name,
    cognito_admin_email     = var.cognito_config.cognito_admin_email,
    S3_BACKUP_BUCKET        = var.enable_s3_backup ? aws_s3_bucket.backup_bucket.bucket : ""
  })
  
  tags = merge(
    var.ec2_additional_tags,
    {
      Name = var.ec2_config.name
      FQDN = var.ec2_config.fqdn
      Description = var.ec2_config.description
    },
  )
}

resource "aws_eip" "eip" {
  count    = var.ec2_instance_count
  domain = "vpc"
  instance = "${aws_instance.ec2[count.index].id}"
  tags = {
    Name = "${var.ec2_config.fqdn}"
    }
}

# If Cognito is enabled, use the Cognito template, otherwise use the basic template
locals {
  meshcentral_config_template = var.cognito_config.cognito_auth ? "${path.module}/cognito_mesh_config.json.tftpl" : "${path.module}/basic_mesh_config.json.tftpl"
}

locals {
  meshcentral_config_rendered = templatefile(local.meshcentral_config_template, {
    admin_user              = var.mesh_config["admin_user"]
    admin_pass              = var.mesh_config["admin_pass"]
    admin_email             = var.mesh_config["admin_email"]
    mesh_login_title        = var.mesh_config["mesh_login_title"]
    letsencrypt_email       = var.letsencrypt_config.letsencrypt_emailAddress
    letsencrypt_env         = var.letsencrypt_config.letsencrypt_env
    fqdn                    = var.ec2_config.fqdn
    space_separated_domains = local.space_separated_domains

    # If Cognito is enabled, pass these
    cognito_client_id        = var.cognito_config["client_id"]
    cognito_client_secret    = var.cognito_config["client_secret"]
    cognito_issuer           = var.cognito_config["issuer"]
    cognito_logout_url       = var.cognito_config["logoutUrl"]
    cognito_token_url        = var.cognito_config["tokenUrl"]
    cognito_domain           = var.cognito_config["cognito_domain"]
    cognito_custom_domain    = var.cognito_config["cognito_custom_domain"]
    cognito_admin_oidc       = var.cognito_config["cognito_admin_oidc"]

    s3_backup_bucket         = var.enable_s3_backup ? aws_s3_bucket.backup_bucket.bucket : ""
  })
}

resource "aws_ssm_parameter" "meshcentral_config" {
  name        = "/meshcentral/${var.ec2_config.name}/config.json"
  description = "MeshCentral ${var.ec2_config.name} configuration JSON"
  type        = "SecureString"
  overwrite   = true
  value       = local.meshcentral_config_rendered
}

# Create Route 53 DNS Record
resource "aws_route53_record" "dns" {
  allow_overwrite = true
  count   = var.ec2_instance_count
  zone_id = var.r53_config.zone_id
  name    = var.ec2_config.fqdn
  type    = var.r53_config.type
  ttl     = var.r53_config.ttl
  records = [aws_eip.eip[count.index].public_ip]
}

### Gets latest Amazon AMI for deployment ###
data "aws_ami" "amazon" {
owners      = ["amazon"]
most_recent = true

  filter {
      name   = "name"
      values = ["al2023-ami-2023*"] # Amazon Linux 2023
  }

  filter {
      name   = "architecture"
      values = ["arm64"]
  }

  filter {
      name   = "root-device-type"
      values = ["ebs"]
  }
}

###################### LOCALS VARIABLES ######################

### Used for things that require 1 subnet per az.  Think ALB requirements
locals {
  az_to_subnet_private = {
    for subnet_id in data.aws_subnets.private.ids :
    data.aws_subnet.subnet[subnet_id].availability_zone => subnet_id...
  }

  private_unique_subnet_ids = [
    for az, ids in local.az_to_subnet_private : ids[0]
  ]

  az_to_subnet_public = {
    for subnet_id in data.aws_subnets.public.ids :
    data.aws_subnet.subnet[subnet_id].availability_zone => subnet_id...
  }

  public_unique_subnet_ids = [
    for az, ids in local.az_to_subnet_public : ids[0]
  ]
}

### Used to randomize ec2 subnet placement
resource random_id index {
  byte_length = 2
}

resource "random_shuffle" "private-subnets" {
  input        = data.aws_subnets.private.ids
  result_count = 1
}

resource "random_shuffle" "public_subnets" {
  input        = local.public_unique_subnet_ids
  result_count = 1
}

locals {
  private_subnet_ids_list = tolist(data.aws_subnets.private.ids)
  private_subnet_ids_random_index = random_id.index.dec % length(data.aws_subnets.private.ids)
  private_instance_subnet_id = local.private_subnet_ids_list[local.private_subnet_ids_random_index]
}

locals {
  public_subnet_ids_list = tolist(data.aws_subnets.public.ids)
  public_subnet_ids_random_index = random_id.index.dec % length(data.aws_subnets.public.ids)
  public_instance_subnet_id = local.public_subnet_ids_list[local.public_subnet_ids_random_index]
}

# Optional S3 bucket for backups
resource "aws_s3_bucket" "backup_bucket" {
  count = var.enable_s3_backup ? 1 : 0
  bucket = "${var.ec2_config.name}-meshcentral-backup"
  acl    = "private"

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = merge(
    var.ec2_additional_tags,
    {
      Name = "${var.ec2_config.name}-backup-bucket"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "backup_bucket_block" {
  count = var.enable_s3_backup ? 1 : 0
  bucket = aws_s3_bucket.backup_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "backup_bucket_policy" {
  count = var.enable_s3_backup ? 1 : 0
  bucket = aws_s3_bucket.backup_bucket[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ec2_role.arn
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.backup_bucket[0].arn,
          "${aws_s3_bucket.backup_bucket[0].arn}/*"
        ]
      }
    ]
  })
}
