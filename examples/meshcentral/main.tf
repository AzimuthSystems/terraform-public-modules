module "meshcentral" {
  source = "git::https://github.com/AzimuthSystems/terraform-public-modules.git//modules/meshcentral?ref=main"

  vpc_account_tag          = var.vpc_account_tag
  vpc_uniqueid_tag         = var.vpc_uniqueid_tag
  subnet_public_tag        = var.subnet_public_tag
  subnet_private_tag       = var.subnet_private_tag
  r53_config               = var.r53_config
  aws_region               = var.aws_region
  environment              = var.environment
  ec2_instance_count       = var.ec2_instance_count
  ec2_config               = var.ec2_config
  ec2_additional_tags      = var.ec2_additional_tags
  letsencrypt_config       = var.letsencrypt_config
  cognito_config           = var.cognito_config
  mesh_config              = var.mesh_config
}
