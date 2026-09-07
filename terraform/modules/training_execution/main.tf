# SageMaker training execution role + ECR image repository (GitHub #61,
# consumed by #54 "Managed training job"). No S3 bucket is created here —
# var.bucket_arn must point at an existing bucket (terraform/envs/aws-training).

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_ecr_repository" "training" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE" # a tag must always point at one build; not caller-configurable

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "training" {
  repository = aws_ecr_repository.training.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_untagged_image_expiry_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

data "aws_iam_policy_document" "execution" {
  statement {
    sid       = "ListTrainingBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      # Both the bare prefix (a caller listing exactly "training") and any
      # deeper prefix under it must match, or ListBucket calls that pass the
      # root prefix without a trailing "/*" segment are denied.
      values = [var.bucket_training_prefix, "${var.bucket_training_prefix}/*"]
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
    resources = ["${var.bucket_arn}/${var.bucket_training_prefix}/*"]
  }

  statement {
    sid       = "EcrAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # required by the ECR API; cannot be scoped to a repository ARN
  }

  statement {
    sid    = "EcrPullTrainingImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [aws_ecr_repository.training.arn]
  }

  statement {
    sid    = "SageMakerTrainingLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/aws/sagemaker/TrainingJobs:*"]
  }
}

resource "aws_iam_role_policy" "execution" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}
