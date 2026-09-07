output "execution_role_arn" {
  description = "ARN of the SageMaker training execution role. Sensitive because it embeds the AWS account ID."
  value       = aws_iam_role.execution.arn
  sensitive   = true
}

output "execution_role_name" {
  description = "Name of the SageMaker training execution role."
  value       = aws_iam_role.execution.name
}

output "ecr_repository_url" {
  description = "Repository URL for docker push/pull. Embeds the AWS account ID."
  value       = aws_ecr_repository.training.repository_url
  sensitive   = true
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.training.arn
  sensitive   = true
}
