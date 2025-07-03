output "meshcentral_instance_public_ip" {
  description = "Public IP of the MeshCentral instance"
  value       = module.meshcentral.instance_public_ip
}

output "meshcentral_instance_public_dns" {
  description = "Public DNS of the MeshCentral instance"
  value       = module.meshcentral.instance_public_dns
}

output "meshcentral_instance_id" {
  description = "Instance ID"
  value       = module.meshcentral.instance_id
}

output "meshcentral_instance_arn" {
  description = "Instance ARN"
  value       = module.meshcentral.instance_arn
}

output "meshcentral_instance_private_ip" {
  description = "Private IP address"
  value       = module.meshcentral.instance_private_ip
}

output "meshcentral_route53_record_fqdn" {
  description = "FQDN of the Route53 record"
  value       = module.meshcentral.route53_record_fqdn
}

output "meshcentral_config_ssm_parameter" {
  description = "SSM parameter storing MeshCentral config"
  value       = module.meshcentral.ssm_config_parameter_name
}