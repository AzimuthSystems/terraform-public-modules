# Terraform Module: MeshCentral on Amazon Linux 2023 (ARM)

This Terraform configuration provisions a **MeshCentral Remote Management Server** running on an EC2 ARM64 instance using **Amazon Linux 2023**, fully automated with:

- Secure configuration stored in AWS Systems Manager Parameter Store
- Automatic DNS configuration in Route53
- Automatic Let's Encrypt certificate provisioning (via Certbot)
- Optional AWS Cognito integration for OIDC authentication
- Cloud-init bootstrapping to install and configure MeshCentral on launch

---

## Features

✅ **ARM64 Amazon Linux 2023** for cost-effective Graviton instances  
✅ **Route53 DNS** A records  
✅ **Elastic IP** association  
✅ **SSM Parameter Store** secure storage of `config.json`  
✅ **Cognito OIDC authentication support**  
✅ **Customizable hostnames, domains, and tags**

---

## Requirements

- Terraform >= 1.3
- AWS CLI configured with sufficient permissions:
  - EC2
  - SSM
  - IAM
  - Route53
- An existing VPC with **public and private subnets** tagged appropriately as well as a VPC Tag:
  - VPC tag `Account=AccountName`
  - VPC tag `UniqueID=12345678`
  - Subnet tag `Type=Public`
  - Subnet tag `Type=Private`
- A Route53 hosted zone for your domain

**Note:** If you plan to enable Cognito authentication (`cognito_auth = true`), you must also have a working AWS Cognito User Pool and App Client set up. If you do **not** wish to use Cognito authentication, you can disable it by setting `cognito_auth = false` in the `cognito_config` variable.

---

## Variables

| Variable                 | Description                                                                                     |
|--------------------------|-------------------------------------------------------------------------------------------------|
| `aws_region`             | AWS region where resources will be created                                                     |
| `environment`            | Environment name (e.g., "prod", "dev") used for tagging                                        |
| `vpc_tags`               | Map of tags used to identify the VPC (e.g., Account and UniqueID)                              |
| `subnet_tags`            | Map of tags to identify public and private subnets (e.g., Type = Public or Private)            |
| `ec2_instance_count`     | Number of EC2 instances to launch                                                              |
| `ec2_config`             | Map of EC2 instance configuration options (name, fqdn, description, key_name, profile, instance_type) |
| `ec2_additional_tags`    | Additional tags to apply to EC2 instances                                                      |
| `r53_config`             | Route53 DNS configuration (zone_id, record type, TTL)                                         |
| `letsencrypt_config`     | Config settings for letsencrypt                                                               |
| `mesh_config`            | Map of MeshCentral server configuration parameters (e.g., login title, admin email)           |
| `cognito_config`         | Map of AWS Cognito OIDC configuration parameters (client_id, client_secret, issuer, logoutUrl, tokenUrl, cognito_domain, cognito_custom_domain) |

---

## Usage Example - Example configs can be found here -> [examples/meshcentral](https://github.com/AzimuthSystems/terraform-public-modules/tree/main/examples/meshcentral)

```hcl
module "meshcentral" {
  source = "./meshcentral-terraform"

  aws_region = "us-west-2"
  environment = "prod"

  vpc_tags = {
    Account  = "AccountName"
    UniqueID = "12345678"
  }

  subnet_tags = {
    Public  = "Public"
    Private = "Private"
  }

  ec2_instance_count = 1

  ec2_config = {
    name          = "meshtest.example.net"
    fqdn          = "meshtest.example.net"
    description   = "MeshCentral Server"
    key_name      = "MyKeyPair"
    profile       = "EC2-SSM-Role"
    instance_type = "t4g.micro"
  }

  ec2_additional_tags = {
    Project = "MeshCentral"
    Owner   = "Admin"
  }

  r53_config = {
    zone_id = "EXAMPLE_ZONE_ID"
    type    = "A"
    ttl     = "60"
  }

  letsencrypt_config = {
    letsencrypt_emailAddress = "name@example.net"
    letsencrypt_env = false  # Set to true for production, false for staging
    certbot_domains = [
      "meshtest.example.net"
    ]
    site_domain = "example.net"
  }

  mesh_config = {
    mesh_login_title = "My MeshCentral"
    admin_user       = "admin"
    admin_pass       = "123ChangeThis!"
    admin_email_mesh = "meshadmin@example.net"
  }

  cognito_config = {
    cognito_auth            = true|false
    client_id               = "your-cognito-client-id"
    client_secret           = "your-cognito-client-secret"
    issuer                  = "https://cognito-idp.us-west-2.amazonaws.com/your_pool_id"
    logoutUrl               = "https://yourdomain.auth.us-west-2.amazoncognito.com/logout"
    tokenUrl                = "https://yourdomain.auth.us-west-2.amazoncognito.com/oauth2/token"
    cognito_domain          = "yourdomain.auth.us-west-2.amazoncognito.com"
    cognito_custom_domain   = "auth.example.net"
    cognito_admin_oidc      = "sub id for account you want to have siteadmin"
    cognito_admin_full_name = "Example User"
    cognito_admin_email     = "admin@example.com"
  }
}
```

---

## Cost Estimate

Deploying this infrastructure will incur charges on your AWS account. Approximate costs include:

- EC2 t4g.micro instance: around $6 per month (varies by region and usage)
- Elastic IP address: nominal charges if associated with a running instance
- Route53 hosted zone and DNS queries: small monthly fees depending on usage
- SSM Parameter Store: free for standard parameters within limits
- AWS Cognito: charges apply if enabled, based on active users and usage

Please review the [AWS Pricing Calculator](https://calculator.aws/#/) and AWS pricing pages to get accurate cost estimates tailored to your region and usage patterns.