# HCP Terraform Provider Variable Map

This document maps **planned** HCP Terraform workspace variables to Terraform inputs and provider environment variables. Provider blocks are not wired yet in `terraform/envs/ibm-dev` (no tracking issue — IBM credits are currently exhausted, see `docs/credits/inventory.md`) or `terraform/envs/oracle-dev` (#48); tables below describe what operators should configure once wiring lands. AWS provider wiring landed with #47 (`terraform/envs/aws-training`) — see the AWS section below, which is active now rather than planned.

**Do not commit values** for sensitive variables.

## Variable categories in HCP

HCP Terraform distinguishes two categories:

| Category | HCP UI label | When to use |
|---|---|---|
| **Terraform variable** | Terraform variable | Key must match a `variable` block in the workspace working directory exactly (e.g. `location`, `ibmcloud_api_key`). |
| **Environment variable** | Environment variable | Exposed to the provider plugin / shell; not declared as Terraform `variable` blocks (e.g. `OCI_TENANCY_OCID`, `IBMCLOUD_API_KEY` when read directly by the provider). |

Use the **exact HCP key** shown in each table. Display names like `IBMCLOUD_API_KEY` are environment variables unless a matching Terraform `variable` block exists.

See also:
- `docs/hcp/workspaces.md` — workspace list and boundaries
- `docs/hcp/vcs-integration.md` — VCS and speculative plan setup
- `scripts/hcp/bootstrap-workspaces.sh` — idempotent workspace + scaffold variable setup
- `providers/ibm/bootstrap.md` — IBM CLI and bootstrap order
- `providers/oracle/bootstrap.md` — OCI CLI and bootstrap order

## Common variables (all active workspaces)

Attach via a shared HCP variable set where possible. Use **Terraform variable** category when a matching `variable` block exists; otherwise **Environment variable** for audit-only keys.

| HCP key | Category | Sensitive | Terraform variable (when used) | Notes |
|---|---|---|---|---|
| `environment` | terraform | no | `environment` | e.g. `dev` |
| `owner` | terraform | no | `owner` | Team or operator label (no account IDs) |
| `repo` | env | no | n/a | Set to `rmems/Dioscuri-Cloud` for audit context |
| `budget_cap_usd` | env | no | n/a | Per-experiment cap reference; see `docs/credits/usage-policy.md` |
| `provider_role` | env | no | n/a | e.g. `control-plane`, `ibm-dev`, `oracle-dev` |

## Scaffold inputs (active today)

These Terraform variables exist in the repo **now** and must be set in HCP (or rely on code defaults) so speculative plans do not fail on missing inputs.

### `dioscuri-cloud-hcp-core` (`infra/terraform/environments/dev`)

| HCP key | Category | Sensitive | Default in code | Notes |
|---|---|---|---|---|
| `project_name` | terraform | no | `dioscuri-cloud` | Logical project name |
| `environment` | terraform | no | `dev` | Environment label |
| `owner` | terraform | no | `raulmc` | Owner or team label |

No provider credentials. Common variables only.

### `dioscuri-cloud-ibm-dev` (`terraform/envs/ibm-dev`)

| HCP key | Category | Sensitive | Default in code | Notes |
|---|---|---|---|---|
| `location` | terraform | no | `us-south` | IBM region for artifacts |
| `artifact_bucket_name` | terraform | no | `dioscuri-cloud-dev-artifacts` | Planned bucket; not created yet |
| `service_account_name` | terraform | no | `dioscuri-artifact-reader` | Service ID name (future) |

### `dioscuri-cloud-oracle-dev` (`terraform/envs/oracle-dev`)

| HCP key | Category | Sensitive | Default in code | Notes |
|---|---|---|---|---|
| `location` | terraform | no | `us-phoenix-1` | OCI region for artifacts |
| `artifact_bucket_name` | terraform | no | `dioscuri-cloud-dev-artifacts` | Bootstrapped manually; import before first apply (#48) |
| `service_account_name` | terraform | no | `dioscuri-artifact-reader` | IAM principal name (future) |

## IBM Cloud (`dioscuri-cloud-ibm-dev`) — planned provider auth

Workspace: `dioscuri-cloud-ibm-dev`  
Working directory: `terraform/envs/ibm-dev`

Active once IBM provider block is added (no tracking issue yet — IBM credits are currently exhausted, see `docs/credits/inventory.md`):

| HCP key | Category | Sensitive | Terraform variable (future) | Notes |
|---|---|---|---|---|
| `IBMCLOUD_API_KEY` | env | yes | `ibmcloud_api_key` | API key from IBM console; never commit |
| `IBMCLOUD_REGION` | env | no | `ibmcloud_region` | Single home region for dev |
| `IBMCLOUD_RESOURCE_GROUP` | env | no | `ibmcloud_resource_group` | e.g. `dioscuri-cloud` (name only in docs) |

Planned transitional auth: static API key in HCP until OIDC/federation is configured (follow-up issue). Not active until provider wiring lands.

## Oracle Cloud (`dioscuri-cloud-oracle-dev`) — planned provider auth

Workspace: `dioscuri-cloud-oracle-dev`  
Working directory: `terraform/envs/oracle-dev`

Active once OCI provider block is added (#48):

| HCP key | Category | Sensitive | Terraform variable (future) | Notes |
|---|---|---|---|---|
| `OCI_TENANCY_OCID` | env | yes | `tenancy_ocid` | Do not commit OCIDs to git |
| `OCI_USER_OCID` | env | yes | `user_ocid` | |
| `OCI_FINGERPRINT` | env | yes | `fingerprint` | API key fingerprint |
| `OCI_PRIVATE_KEY` | env | yes | `private_key` | PEM contents; HCP sensitive only |
| `OCI_REGION` | env | no | `region` | Home region for dev |
| `OCI_COMPARTMENT_OCID` | env | yes | `compartment_ocid` | Target compartment for resources |

Planned transitional auth: key-based `~/.oci/config` locally; mirror to HCP for remote runs. Migrate to workload identity when available. Not active until provider wiring lands.

## AWS (`dioscuri-cloud-aws-training`) — provider auth (env-native, active as of #47)

Workspace: `dioscuri-cloud-aws-training`  
Working directory: `terraform/envs/aws-training`

Unlike IBM/Oracle, AWS credentials and region are HCP **environment**
variables read natively by the AWS provider's SDK credential chain.
`provider "aws" {}` in `terraform/envs/aws-training/providers.tf` takes
**no explicit arguments**, and there are **no** matching `variable` blocks
for these in Terraform:

| HCP key | Category | Sensitive | Terraform variable | Notes |
|---|---|---|---|---|
| `AWS_REGION` | env | no | none — read by provider SDK | e.g. `us-east-1` |
| `AWS_ACCESS_KEY_ID` | env | yes | none — read by provider SDK | Prefer OIDC roles later (future issue); keep keys temporary |
| `AWS_SECRET_ACCESS_KEY` | env | yes | none — read by provider SDK | Never commit |

Terraform variables (scaffold inputs, active now):

| HCP key | Category | Sensitive | Default in code | Notes |
|---|---|---|---|---|
| `bucket_name` | terraform | no | none (required) | Globally unique; set in HCP workspace, never committed |
| `force_destroy` | terraform | no | `false` | Keep `false` for the persistent training bucket |
| `noncurrent_version_expiration_days` | terraform | no | `90` | Bounds versioned-object storage cost |
| `abort_incomplete_multipart_upload_days` | terraform | no | `7` | Required lifecycle rule (issue #47) |

## Never commit

- `.tfvars`, `*.auto.tfvars`, `terraform.tfvars`
- `*.tfstate`, `*.tfstate.backup`, `.terraform/`
- Provider CLI config with secrets (`~/.ibmcloud/`, `~/.oci/config`, private keys)
- HCP tokens, API keys, service account JSON, screenshots with account identifiers
