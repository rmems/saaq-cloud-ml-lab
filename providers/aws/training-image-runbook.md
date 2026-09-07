# AWS training image runbook

Build/push flow for the CUDA training image (`training/docker/`) and how it
plugs into the two Terraform modules from GitHub #61:
`terraform/modules/training_node/` (GPU EC2 instance) and
`terraform/modules/training_execution/` (SageMaker execution role + ECR).

No GPU is required to build or push the image — only to run it.

## 1. Build the image locally

```bash
cd training/docker
docker build -t dioscuri-cloud-training:local .
docker run --rm dioscuri-cloud-training:local --help
```

## 2. Provision the ECR repository (once)

Apply `terraform/modules/training_execution/` from an env (e.g.
`terraform/envs/aws-training`, passing `bucket_arn` from that env's own S3
bucket output). This creates the ECR repository and outputs
`ecr_repository_url`.

## 3. Authenticate and push

```bash
AWS_REGION=<region>
ECR_REPOSITORY_URL=<ecr_repository_url output>

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REPOSITORY_URL"

docker tag dioscuri-cloud-training:local "$ECR_REPOSITORY_URL:<tag>"
docker push "$ECR_REPOSITORY_URL:<tag>"
```

Use an immutable, meaningful tag (e.g. a short git SHA) — the repository's
lifecycle policy expires untagged images automatically, and tag mutability
is `IMMUTABLE` by default so a tag can't silently point at a different build
later.

## 4. Finding a GPU AMI for `terraform/modules/training_node`

`ami_id` has no default because Deep Learning AMIs are region- and
version-specific. Look up the current AMI for your region via SSM:

```bash
aws ssm get-parameters \
  --names /aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-pytorch-2.4/latest/ami-id \
  --region "$AWS_REGION" \
  --query 'Parameters[0].Value' --output text
```

Record the resolved AMI ID and region in the run's issue/PR per
`docs/runbooks/gpu-smoke-test-readiness.md` item 4 (provider/region/SKU
selection) — do not hardcode it into Terraform defaults, since it goes stale
and varies by region.

## 5. Running the image

- **EC2** (`terraform/modules/training_node`): SSH in (restricted to
  `operator_cidrs`) and `docker run --gpus all <ecr_repository_url>:<tag> ...`,
  or use user-data to pull and run on boot.
- **SageMaker** (`terraform/modules/training_execution`): reference
  `ecr_repository_url:<tag>` as the training job's container image, and
  `execution_role_arn` as the job's execution role.

## Before any of this touches real AWS spend

Complete `docs/runbooks/gpu-smoke-test-readiness.md` in full and record a
`cost-ledger.md` row first.
