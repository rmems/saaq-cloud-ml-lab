# Terraform Layout

This repo uses Terraform to define reusable infrastructure primitives for cloud ML experiments.

Design principles:
- Keep modules provider-aware but provider-agnostic at the interface.
- Keep environments small and composable.
- Do not commit credentials, state files, or `.terraform/` directories.

## Directory structure

```text
terraform/
  modules/                   Reusable, provider-agnostic interfaces
    artifact_bucket/         Object storage bucket/container abstraction
    service_account/         IAM principal + minimal bindings abstraction

  envs/                      Environment stacks that compose modules
    ibm-dev/                 IBM Cloud dev (HCP: dioscuri-cloud-ibm-dev)
    oracle-dev/              Oracle Cloud dev (HCP: dioscuri-cloud-oracle-dev)
    gcp-artifacts/           GCP artifacts scaffold (implementation deferred)
    aws-training/            AWS S3 training bucket + IAM (HCP: dioscuri-cloud-aws-training)

  aws/                       Provider-specific notes (legacy placeholder)
  azure/                     Provider-specific notes (legacy placeholder)
  digitalocean/              Provider-specific notes (legacy placeholder)
```

Control-plane onboarding (no provider resources) lives under `infra/terraform/environments/dev` and maps to HCP workspace `dioscuri-cloud-hcp-core`. See `infra/terraform/README.md`.

## Modules vs envs

- `modules/*` define stable inputs/outputs. Implementations may be provider-specific internally, but the interface should remain consistent.
- `envs/*` are thin compositions for a single provider/account/project boundary. Each env should be safe to `plan`/`apply` independently.

## State and HCP Terraform

- Organization: `Dioscuri-Cloud`
- One HCP workspace per env folder; see `docs/hcp/workspaces.md`
- Variable mapping: `docs/hcp/provider-variable-map.md`
- VCS integration: `docs/hcp/vcs-integration.md`

Tracked code does not include `terraform { cloud { ... } }` blocks; VCS-connected workspaces receive remote backend configuration from HCP. For local CLI against remote state, copy `infra/terraform/remote_state_override.tf.example` to an untracked `*_override.tf` in the target directory.

Do not commit local state files or backend credentials.

## Formatting

Terraform files should be kept `terraform fmt` clean.

## GitHub Actions vs HCP Terraform

This repo runs basic Terraform checks in GitHub Actions for pull requests:
- `terraform fmt -check -recursive`
- `terraform init -backend=false` + `terraform validate` for module skeletons
- `infra/terraform/environments/dev`, `infra/terraform/environments/vultr-dev`, `terraform/envs/ibm-dev`, `terraform/envs/oracle-dev`, and `terraform/envs/aws-training` validate without provider credentials

HCP Terraform runs remote plans/applies with workspace variables and credentials configured only in HCP.

See also: `docs/hcp/vcs-integration.md`.
