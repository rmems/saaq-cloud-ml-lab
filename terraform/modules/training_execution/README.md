# Module: training_execution

SageMaker training execution role + ECR image repository (GitHub #61,
consumed by #54 "Managed training job (SageMaker, Azure ML backup)").

## Resources Managed

- IAM role assumable by `sagemaker.amazonaws.com`, with an inline
  least-privilege policy scoped to:
  - Read/write on `<bucket_arn>/<bucket_training_prefix>/*` (default prefix
    `training/`, per `docs/training/artifact-layout.md`)
  - Pull access to this module's own ECR repository only
  - CloudWatch Logs for `/aws/sagemaker/TrainingJobs*`
- ECR repository (`aws_ecr_repository`) with scan-on-push, AES256 encryption,
  and immutable tags by default
- ECR lifecycle policy expiring untagged images after
  `var.ecr_untagged_image_expiry_days` days

No S3 bucket is created here — pass the ARN of an existing bucket (e.g. the
output of `terraform/envs/aws-training`) via `var.bucket_arn`.

## Inputs

See `variables.tf`. Required: `bucket_arn`. `tags` is a passthrough map —
callers should include `owner`, `github`, `pr`, and `teardown_by` per
`docs/credits/usage-policy.md`.

## Example

```hcl
module "training_execution" {
  source = "../../modules/training_execution"

  bucket_arn = module.aws_training_bucket.bucket_arn # from terraform/envs/aws-training

  tags = {
    owner       = "rmems"
    github      = "54"
    pr          = "<pr-number>"
    teardown_by = "<YYYY-MM-DD>"
  }
}
```

## Building and pushing the training image

See `providers/aws/training-image-runbook.md` for the full
`docker build` / `docker push` flow against `ecr_repository_url`.
