# Module: training_node

Bounded AWS GPU training instance + IAM instance profile (GitHub #61,
consumed by #53 "Bounded GPU training node on AWS").

## Resources Managed

- IAM role + instance profile for the node (always created; $0 cost)
- Optional attachment of caller-supplied policy ARNs (e.g. the
  `training_bucket_rw` policy output by `terraform/envs/aws-training`)
- Security group allowing SSH only from `var.operator_cidrs`
- Optional EC2 key pair (only if `var.ssh_public_key` is set)
- `count = var.instance_count` GPU instance(s) — **defaults to 0**

## Safety

- `instance_count` defaults to `0`. Instantiating this module with no
  overrides creates the IAM/security-group primitives but **zero compute**.
  Set `instance_count` explicitly (max 2) to launch nodes.
- `operator_cidrs` has no usable default — the placeholder `10.0.0.0/8`
  fails validation, forcing the caller to set real CIDRs.
- Before setting `instance_count > 0`, complete
  `docs/runbooks/gpu-smoke-test-readiness.md`.

## Inputs

See `variables.tf`. Notable required inputs (no default): `ami_id`,
`subnet_id`, `vpc_id`. `tags` is a passthrough map — this module applies
whatever is given; callers should include `owner`, `github`, `pr`, and
`teardown_by` per `docs/credits/usage-policy.md`.

## Example

```hcl
module "gpu_node" {
  source = "../../modules/training_node"

  name           = "dioscuri-cloud-training-smoke"
  instance_count = 1
  ami_id         = "ami-xxxxxxxxxxxxxxxxx" # Deep Learning AMI GPU CUDA, region-specific
  subnet_id      = "subnet-xxxxxxxx"
  vpc_id         = "vpc-xxxxxxxx"
  operator_cidrs = ["203.0.113.0/24"]

  # iam_policy_arns takes IAM *policy* ARNs, not role ARNs — e.g. the #47
  # training_bucket_rw policy output by terraform/envs/aws-training.
  iam_policy_arns = [module.aws_training_bucket.training_bucket_rw_policy_arn]

  tags = {
    owner       = "rmems"
    github      = "53"
    pr          = "<pr-number>"
    teardown_by = "<YYYY-MM-DD>"
  }
}
```
