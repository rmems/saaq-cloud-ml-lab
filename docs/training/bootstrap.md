# Training environment bootstrap (Issue #62)

One script, `scripts/training-bootstrap.sh`, verifies the AWS training
prerequisites are in place before any job runs — it never provisions
anything. Steps 1-4 are read-only API calls
(`sts:GetCallerIdentity`, `s3:ListBucket`, an authenticated HCP workspace
lookup, optionally `ecr:GetAuthorizationToken`/pull). **Step 5's GPU path is
the one exception**: it dispatches a real command via `ssm:SendCommand` (a
write IAM action, not read-only) and waits for it to finish — see step 5
below. It fails closed: each numbered check must pass before the next one
runs.

## What it checks, in order

1. **HCP Terraform authentication** — `terraform`, `curl`, and `jq` are
   installed, `TF_TOKEN_app_terraform_io` is set (or read from
   `~/.terraform.d/credentials.tfrc.json`, from `terraform login`), **and**
   that token successfully looks up org `Dioscuri-Cloud`, workspace
   `dioscuri-cloud-aws-training` (`terraform/envs/aws-training`) via a real,
   authenticated, read-only HCP API request (the same request pattern as
   `scripts/hcp/bootstrap-workspaces.sh`) — not just that a token/file is
   present, which an invalid, expired, or unrelated token would also pass.
2. **AWS caller identity** — `aws sts get-caller-identity` succeeds for
   whatever AWS credentials are active (profile, env vars, or instance
   role), and the resolved account number is printed so the operator can
   confirm it's the training account. Set `TRAINING_EXPECTED_AWS_ACCOUNT_ID`
   to make this a hard failure instead of an eyeball check.
3. **S3 training bucket probe** — lists the `training/` prefix of the
   bucket named by `TRAINING_BUCKET_NAME` (docs/training/artifact-layout.md).
4. **Training image** — if `TRAINING_ECR_REPOSITORY_URL` is set, logs
   Docker in to that ECR registry (via `aws ecr get-login-password`, using
   the region parsed out of the URL itself — ECR auth tokens are
   region-scoped, so the caller's own default region is not used even if
   it differs; AWS credentials alone do not authenticate the Docker
   client) and pulls `:TRAINING_IMAGE_TAG` (default `latest`). Otherwise builds
   `training/docker/` locally as `dioscuri-cloud-training:bootstrap-check`
   — and fails with a specific, actionable message (not a generic build
   error) if that directory doesn't exist yet in this checkout, which is
   expected before Issue #61 lands.
5. **Optional dry-run** — if `TRAINING_GPU_INSTANCE_ID` is set, dispatches
   `nvidia-smi` to it via `ssm:SendCommand` **and blocks on
   `aws ssm wait command-executed`** until it actually finishes, rather than
   just checking that the asynchronous dispatch was accepted (a successful
   dispatch does not mean `nvidia-smi` itself succeeded). This step requires
   `ssm:SendCommand` **and** `ssm:GetCommandInvocation` (the waiter polls
   this — a distinct permission, not covered by `ssm:SendCommand` alone) on
   the calling identity, plus the target instance's own SSM Agent/
   instance-profile registration (a separate, node-side permission) — it is
   not read-only. If `TRAINING_SAGEMAKER_JOB_NAME`
   is set instead, describes that job (read-only). If neither is set, this
   step is skipped — expected before #53/#54 provision an actual node or job.

## Usage

```bash
export TRAINING_BUCKET_NAME=<bucket_name from your HCP workspace variables>
# Optional, once #61's image is pushed to ECR:
export TRAINING_ECR_REPOSITORY_URL=<ecr_repository_url output>
export TRAINING_IMAGE_TAG=<tag>
# Optional, once #53 or #54 has provisioned compute:
export TRAINING_GPU_INSTANCE_ID=<i-...>
# or
export TRAINING_SAGEMAKER_JOB_NAME=<job-name>

./scripts/training-bootstrap.sh
```

## Required environment variables and where they live

This script runs in the operator's **local** shell — it reads local AWS CLI
configuration and local process environment variables only. It does **not**
read HCP Terraform workspace variables remotely; those exist for
`terraform apply` runs on HCP's own infrastructure, not for a script running
on your machine. If you manage credentials via HCP workspace variables, set
the equivalent values in your local shell before running this script (or
via an SSO/credential-process bridge you already use).

| Variable | Required | Source |
|---|---|---|
| `AWS_PROFILE` or `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_REGION` | Yes | Local AWS CLI profile or shell environment variables for the training account. Never committed. |
| `AWS_SESSION_TOKEN` | Only with temporary/STS credentials | Required alongside the access key/secret pair above when using temporary credentials — see `providers/aws/managed-ml-smoke-test.md`. Never committed. |
| `TF_TOKEN_app_terraform_io` (or `terraform login`) | Yes | Local HCP Terraform CLI credentials. Never committed. |
| `TRAINING_BUCKET_NAME` | Yes | The `bucket_name` value set in the `dioscuri-cloud-aws-training` HCP workspace — copy it into your local shell; this script does not fetch it from HCP. Globally unique; never hardcoded in this repo. |
| `TRAINING_EXPECTED_AWS_ACCOUNT_ID` | No | If set, step 2 fails hard when the active credentials resolve to a different account. Never commit an account ID to this repo — export it locally only. |
| `TRAINING_ECR_REPOSITORY_URL`, `TRAINING_IMAGE_TAG` | No | `ecr_repository_url` output of `terraform/modules/training_execution` once #61's image is pushed (`providers/aws/training-image-runbook.md`). |
| `TRAINING_GPU_INSTANCE_ID` | No | An EC2 instance ID once #53 provisions one via `terraform/modules/training_node`. |
| `TRAINING_SAGEMAKER_JOB_NAME` | No | A SageMaker training job name once #54 launches one. |

No API keys, tokens, or account identifiers are ever written to this repo —
this script only reads environment variables the operator already has set
locally.

## Non-goals

- No MCP/memory sync for agent swarms.
- No MiMo/Kilo/Grok IDE integration.
- No full training job — that's #59, which this bootstrap is a precondition
  for, not a substitute.
