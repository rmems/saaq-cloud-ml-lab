output "bucket_name" {
  description = "S3 bucket name for training datasets/checkpoints/logs."
  value       = aws_s3_bucket.training.id
}

output "bucket_arn" {
  description = "S3 bucket ARN (arn:aws:s3:::<bucket>) — account/region-free, safe to surface."
  value       = aws_s3_bucket.training.arn
}

output "bucket_regional_domain_name" {
  description = "Bucket's regional endpoint hostname, for constructing https:// URIs without embedding account IDs."
  value       = aws_s3_bucket.training.bucket_regional_domain_name
}

output "training_bucket_rw_policy_arn" {
  description = "ARN of the least-privilege IAM policy scoped to this bucket's training/ prefix. Not attached to anything by this PR. Sensitive because IAM policy ARNs embed the AWS account ID."
  value       = aws_iam_policy.training_bucket_rw.arn
  sensitive   = true
}
