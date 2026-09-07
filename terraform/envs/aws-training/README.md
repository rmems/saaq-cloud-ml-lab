# Env: aws-training

AWS S3 environment for training datasets, checkpoints, and logs per
`docs/training/artifact-layout.md` (GitHub #47). Canonical location —
do **not** use `infra/terraform/environments/aws-training`.

## Resources Managed

- Private S3 bucket (`aws_s3_bucket.training`):
  - Versioning enabled
  - Public access fully blocked (`aws_s3_bucket_public_access_block`)
  - Bucket-owner-enforced ownership / ACLs disabled (`aws_s3_bucket_ownership_controls`)
  - Default SSE-S3 (AES256) encryption
  - Lifecycle rules: abort incomplete multipart uploads after
    `var.abort_incomplete_multipart_upload_days` days; expire noncurrent
    object versions after `var.noncurrent_version_expiration_days` days
  - Bucket policy (`aws_s3_bucket_policy.training`) denying any request over
    plain HTTP (`aws:SecureTransport = false`)
- Least-privilege IAM policy (`aws_iam_policy.training_bucket_rw`) scoped to
  the `training/*` prefix of this bucket. **Not attached** to any role/user
  in this PR — a follow-up issue (#61, `training_execution` module) attaches
  it to the SageMaker execution role.

## Non-goals (see issue #47)

- No IBM COS work, no Oracle buckets.
- No staged base-model weights committed or uploaded.
- No SageMaker/GPU compute (#53/#54/#59/#61).
- No AWS OIDC federation yet (future issue; static keys are temporary per
  `docs/hcp/workspaces.md`).

## Required HCP Workspace Variables

**Environment variables** (read natively by the AWS provider's SDK; there
are **no** matching Terraform `variable` blocks for these):

- `AWS_REGION`
- `AWS_ACCESS_KEY_ID` (sensitive)
- `AWS_SECRET_ACCESS_KEY` (sensitive)

**Terraform variables:**

- `bucket_name` — **required, no default.** Must be globally unique across
  all AWS accounts. Set via the HCP workspace UI; never commit a real value.
- `force_destroy` (optional, default `false`)
- `noncurrent_version_expiration_days` (optional, default `90`)
- `abort_incomplete_multipart_upload_days` (optional, default `7`)
- `tags` (optional, default `{}`)

See `docs/hcp/provider-variable-map.md` for the full mapping.

## Usage

```bash
cd terraform/envs/aws-training
terraform init

# PREREQUISITE: update cost-ledger.md with the new resource row(s) before
# apply (see docs/credits/usage-policy.md and cost-ledger.md for the format).

terraform plan
terraform apply
```

> **This PR does not run `terraform apply`.** Manual apply via the HCP UI
> (`dioscuri-cloud-aws-training` workspace) is a separate operator step after
> merge, per repo convention (see `docs/hcp/workspaces.md`). This PR's scope
> is code that plans cleanly: `terraform fmt`, `terraform validate`
> (CI, no credentials required), and a clean **speculative** plan once the
> PR is connected via HCP VCS integration (no apply, no real AWS spend).
>
> **Required:** A `cost-ledger.md` row must exist for this bucket before the
> first real `terraform apply`.
