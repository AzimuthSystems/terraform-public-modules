###############################################################################
# AWS Environment Default Variables
###############################################################################
variable "aws_region" {
  description = "The AWS region to use"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  type = map(string)
  default = {
    env_short = "dev"
    env_long = "Development"
  }
}

###############################################################################
# Terraform Default Network Variables
###############################################################################

data "aws_availability_zones" "available" {}
data "aws_availability_zone" "az_data" {
  count = length(data.aws_availability_zones.available.names)
  name = data.aws_availability_zones.available.names[count.index]
}

variable "vpc_account_tag" {
  description = "The Account tag used to select the VPC"
  type        = string
  default     = "Azimuth"
}

variable "vpc_uniqueid_tag" {
  description = "The UniqueID tag used to select the VPC"
  type        = string
  default     = "123456789"  # Replace with your unique VPC identifier
}

data "aws_vpc" "vpc" {
  filter { 
    name = "tag:Account"
    values = [var.vpc_account_tag]
  }
  filter { 
    name = "tag:UniqueID"
    values = [var.vpc_uniqueid_tag]
  }
}

variable "subnet_private_tag" {
  description = "The 'Type' tag value for private subnets"
  type        = string
  default     = "Private"
}

variable "subnet_public_tag" {
  description = "The 'Type' tag value for public subnets"
  type        = string
  default     = "Public"
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Type = var.subnet_private_tag
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Type = var.subnet_public_tag
  }
}

# Fetch all subnet details for use in locals filtering logic
data "aws_subnet" "subnet" {
  for_each = toset(concat(data.aws_subnets.private.ids, data.aws_subnets.public.ids))
  id       = each.value
}

###############################################################################
# EC2 Variables
###############################################################################

### Number of instances to create
variable "ec2_instance_count" {
  type = number
  default = 1
}

variable "ec2_config" {
  description = "Configuration options for the MeshCentral EC2 instance"
  type = object({
    name           = string
    fqdn           = string
    description    = string
    timezone       = optional(string, "America/Los_Angeles") # Optional: Timezone for the instance, default is set to America/Los_Angeles
    key_name       = string
    instance_profile_override   = optional(string, null) # Optional: Name of an existing IAM instance profile to attach to the EC2 instance
    instance_type  = string
    swap_size     = optional(number, 2) # Optional: Size of the swap file in GB 
    root_block_device = optional(object({
      volume_type = string
      volume_size = number
      volume_iops        = number
      volume_throughput  = number
    }), null)
  })
  default = {
    name           = "meshtest.domainname.net"
    fqdn           = "meshtest.domainname.net"
    description    = "MeshCentral Server"
    timezone       = "America/Phoenix" # Optional: Timezone for the instance, default is set to America/Phoenix
    key_name       = "AWSKeyPairName"
    instance_type  = "t4g.micro"
    swap_size      = 2 # Optional: Size of the swap file in GB
    root_block_device = null
  }
}

variable "ec2_device_names" {
  default = [
    "/dev/xvds",
    "/dev/xvdt",
    "/dev/xvdu",
  ]
}

variable "ec2_additional_tags" {
  default     = {
      BackupSchedule = "Daily"
      Description    = "MeshCentral Server"
      SystemsManager = "Enabled"
    }
  description = "Additional resource tags"
  type        = map(string)
}

###############################################################################
# Route53/LetsEncrypt DNS Options
###############################################################################

# Zone ID for Route53 DNS entries
variable "r53_config" {
  description = "Configuration for the Route 53 record"
  type = object({
    zone_id = string
    name    = string
    type    = string
    ttl     = number
  })
  default = {
    zone_id = "valueZ1234567890" # Replace with your Route53 Zone ID
    name = "value.domainname.net"
    type = "A"
    ttl  = 60
  }
}

variable "letsencrypt_config" {
  type = object({
    letsencrypt_emailAddress = string
    letsencrypt_env = bool # Set to true for production, false for staging
    certbot_domains = list(string)  # List of domains for certbot 
    site_domain = string  # Used in cloud_init template for hosts file
  })
  default = {
    letsencrypt_emailAddress = "name@domainname.net"
    letsencrypt_env = false
    certbot_domains = [
    "meshtest.domainname.net",
    "mesh1.domainname.net"
    ]
    site_domain = "domainname.net"
  }
}

# Using split and join to convert the variable
locals {
  space_separated_domains = join(" ", var.letsencrypt_config.certbot_domains)
}

###############################################################################
# Cognito Options
###############################################################################

variable "cognito_config" {
  type = object({
    cognito_auth            = bool
    client_id               = string
    client_secret           = string
    issuer                  = string
    logoutUrl               = string
    tokenUrl                = string
    cognito_domain          = string
    cognito_custom_domain   = string
    cognito_admin_oidc      = string
    cognito_admin_full_name = string
    cognito_admin_email     = string
  })
  default = {
    cognito_auth            = false
    client_id               = ""
    client_secret           = ""
    issuer                  = ""
    logoutUrl               = ""
    tokenUrl                = ""
    cognito_domain          = ""
    cognito_custom_domain   = ""
    cognito_admin_oidc      = ""
    cognito_admin_full_name = ""
    cognito_admin_email     = ""
  }
}

###############################################################################
# MeshCentral Options
############################################################################### 

# Change these to customize the MeshCentral login page and email settings.
variable "mesh_config" {
  type = map(string)
  default = {
    admin_user = "admin"
    admin_pass = "Ch@ngeme!"
    admin_email = "meshadmin@domainname.net"
    mesh_login_title = "MeshCentral"

  }
}

#Future enhancement - Additional variables for mesh config options.
# https://meshcentral.com/info/meshcentral2-configuration-options/

variable "mesh_welcome_title" {
  default = "Welcome to MeshCentral"
}
variable "mesh_welcome_message" {
  default = "Welcome to MeshCentral.  Please login to continue."
}

variable "mesh_forgot_password_message" {
  default = "Please contact your system administrator to reset your password."
}
variable "mesh_support_email" {
  default = "meshadmin@domainname.net" #Note the spaces at the start to avoid spam bots.
}
variable "mesh_support_url" {
  default = "https://domainname.net/support"
}
variable "mesh_legal_url" {
  default = "https://domainname.net/legal"
}