output "instance_ids" {
  description = "IDs of created GPU instances (empty list when instance_count = 0)."
  value       = aws_instance.node[*].id
}

output "instance_public_ips" {
  description = "Public IPs of created GPU instances. Sensitive to reduce attack-surface reconnaissance in CI/plan logs."
  value       = aws_instance.node[*].public_ip
  sensitive   = true
}

output "security_group_id" {
  description = "Security group ID applied to the node(s)."
  value       = aws_security_group.node.id
}

output "iam_role_arn" {
  description = "ARN of the instance IAM role. Sensitive because it embeds the AWS account ID."
  value       = aws_iam_role.node.arn
  sensitive   = true
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile."
  value       = aws_iam_instance_profile.node.name
}
