variable "name" {
  description = "Base name for the IAM role created by this module."
  type        = string
  default     = "dioscuri-cloud-training-execution"
}

variable "bucket_arn" {
  description = "ARN of the S3 bucket holding training datasets/checkpoints/logs (output of terraform/envs/aws-training). Required — scopes S3 permissions to this bucket only."
  type        = string
}

variable "bucket_training_prefix" {
  description = "Top-level prefix within the bucket that the execution role may read/write (docs/training/artifact-layout.md)."
  type        = string
  default     = "training"
}

variable "ecr_repository_name" {
  description = "ECR repository name for the training image."
  type        = string
  default     = "dioscuri-cloud-training"
}

variable "ecr_untagged_image_expiry_days" {
  description = "Days after which untagged ECR images are expired by the lifecycle policy."
  type        = number
  default     = 14

  validation {
    condition     = var.ecr_untagged_image_expiry_days >= 1 && var.ecr_untagged_image_expiry_days == floor(var.ecr_untagged_image_expiry_days)
    error_message = "ecr_untagged_image_expiry_days must be a positive whole number (ECR lifecycle policies require a non-zero positive integer countNumber)."
  }
}

variable "tags" {
  description = "Tags applied to all resources. Callers should include owner, github, pr, and teardown_by per docs/credits/usage-policy.md — this module does not enforce specific keys, only applies whatever is passed."
  type        = map(string)
  default     = {}
}
