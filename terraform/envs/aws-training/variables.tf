variable "bucket_name" {
  description = "Globally-unique S3 bucket name for training datasets/checkpoints/logs (docs/training/artifact-layout.md). REQUIRED: set via the dioscuri-cloud-aws-training HCP workspace. No default — S3 bucket names are globally unique across all AWS accounts and repo policy forbids committing account-identifying names to git."
  type        = string

  validation {
    condition = (
      can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name)) &&
      !can(regex("\\.\\.", var.bucket_name)) &&
      !can(regex("^[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}$", var.bucket_name))
    )
    error_message = "bucket_name must be 3-63 chars, lowercase letters/digits/hyphens/periods only, start and end with a letter or digit, no consecutive periods, and not look like an IP address (AWS S3 naming rules). Does not cover every reserved prefix/suffix (e.g. 'xn--', '--x-s3'); AWS may still reject some names at apply time."
  }
}

variable "force_destroy" {
  description = "Allow bucket deletion even if non-empty. Keep false for this persistent training bucket; override only for teardown/testing."
  type        = bool
  default     = false
}

variable "noncurrent_version_expiration_days" {
  description = "Days to retain noncurrent (superseded) object versions before expiring them, since versioning is enabled. Bounds storage cost growth."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1 && var.noncurrent_version_expiration_days == floor(var.noncurrent_version_expiration_days)
    error_message = "noncurrent_version_expiration_days must be a positive whole number (AWS requires a non-zero positive integer)."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads are aborted (required lifecycle rule per issue #47)."
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_upload_days >= 1 && var.abort_incomplete_multipart_upload_days == floor(var.abort_incomplete_multipart_upload_days)
    error_message = "abort_incomplete_multipart_upload_days must be a positive whole number (AWS requires a non-zero positive integer)."
  }
}

variable "tags" {
  description = "Additional tags merged into the bucket's/policy's tag set (in addition to owner/github/review_cadence set in main.tf)."
  type        = map(string)
  default     = {}
}
