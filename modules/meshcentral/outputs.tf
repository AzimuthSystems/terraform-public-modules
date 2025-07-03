output "instance_public_ip" {
  description = "Public IP address of the MeshCentral EC2 instance"
  value       = aws_eip.eip[0].public_ip
}

output "instance_id" {
  description = "ID of the MeshCentral EC2 instance"
  value       = aws_instance.ec2[0].id
}

output "instance_arn" {
  description = "ARN of the MeshCentral EC2 instance"
  value       = aws_instance.ec2[0].arn
}

output "instance_public_dns" {
  description = "Public DNS name"
  value       = aws_instance.ec2[0].public_dns
}

output "instance_private_ip" {
  description = "Private IP address"
  value       = aws_instance.ec2[0].private_ip
}

output "route53_record_fqdn" {
  description = "The FQDN of the Route 53 record"
  value       = aws_route53_record.dns[0].fqdn
}

output "ssm_config_parameter_name" {
  description = "SSM parameter name storing MeshCentral config"
  value       = aws_ssm_parameter.meshcentral_config.name
}