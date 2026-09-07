# HCP workspace: dioscuri-cloud-aws-training (org Dioscuri-Cloud).
# Bucket layout contract: docs/training/artifact-layout.md.
# Provider auth: docs/hcp/provider-variable-map.md (AWS section).

locals {
  # var.tags is merged first so the governance tags below always win —
  # callers must not be able to override owner/github/issue/teardown_by/
  # review_cadence via HCP workspace input.
  common_tags = merge(var.tags, {
    owner          = "rmems"
    project        = "dioscuri-cloud-training"
    github         = "47"
    issue          = "47"
    teardown_by    = "n/a-persistent"
    review_cadence = "monthly" # persistent bucket — see docs/credits/usage-policy.md
  })
}

# ── Training bucket (datasets/checkpoints/logs — docs/training/artifact-layout.md) ──

resource "aws_s3_bucket" "training" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "training" {
  bucket = aws_s3_bucket.training.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "training" {
  bucket = aws_s3_bucket.training.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {} # empty filter = applies to all objects; required by the provider schema

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {} # empty filter = applies to all objects; required by the provider schema

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.training]
}

data "aws_iam_policy_document" "training_deny_insecure_transport" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.training.arn, "${aws_s3_bucket.training.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "training" {
  bucket = aws_s3_bucket.training.id
  policy = data.aws_iam_policy_document.training_deny_insecure_transport.json
}

# ── IAM primitive (unattached; #61 attaches this to the SageMaker training
#    execution role — see docs/issues/gh-54.md) ──

data "aws_iam_policy_document" "training_bucket_rw" {
  statement {
    sid       = "ListTrainingBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.training.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      # Both the bare "training" prefix and anything deeper under it must
      # match, or a ListBucket call passing the root prefix without a
      # trailing "/*" segment is denied (same fix as training_execution
      # module — see terraform/modules/training_execution/main.tf).
      values = ["training", "training/*"]
    }
  }

  statement {
    sid    = "ReadWriteTrainingObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = ["${aws_s3_bucket.training.arn}/training/*"]
  }
}

resource "aws_iam_policy" "training_bucket_rw" {
  name        = "${var.bucket_name}-rw"
  description = "Least-privilege read/write access to the training/ prefix of the ${var.bucket_name} bucket (docs/training/artifact-layout.md). Not attached to any principal by this PR."
  policy      = data.aws_iam_policy_document.training_bucket_rw.json

  tags = local.common_tags
}
