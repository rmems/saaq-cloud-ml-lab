# HCP Terraform Workspaces

This document defines the HCP Terraform workspace layout and naming convention for this repo.

HCP Terraform is the control plane for infrastructure state, policy, and drift detection. GPU/ML compute spend is owned by the cloud providers (AWS/Azure/GCP/DO/Vultr/etc.), not by HashiCorp credits.

## Goals
- Keep ownership boundaries clear (one workspace == one blast radius).
- Make it obvious which provider/environment a workspace controls.
- Keep state isolated between providers and between long-lived vs experiment infra.
- Support GitHub VCS integration later without renaming everything.

## Organization Layout
HCP Terraform organization: `Dioscuri-Cloud`.

Recommended structure inside a single HCP Terraform org:
- Folder/Project grouping (in HCP UI):
  - `dioscuri-cloud/core` for shared primitives and control-plane wiring.
  - `dioscuri-cloud/providers/*` for provider-specific infrastructure.
  - `dioscuri-cloud/experiments/*` for short-lived experiment stacks.

If HCP foldering is not used, keep the same grouping via workspace names.

## Naming Convention

Format:

`dioscuri-cloud-<scope>`

Where `<scope>` is one of:
- `hcp-core`
- `<provider>-<purpose>`
- `<provider>-<env>-<purpose>` (only when you truly need separate environments)

Rules:
- Always prefix with `dioscuri-cloud-`.
- Use lowercase and hyphens only.
- Avoid embedding usernames.
- If the workspace is experiment-scoped, include an experiment slug at the end.

Examples (from Issue #3):
- `dioscuri-cloud-hcp-core`
- `dioscuri-cloud-ibm-dev`
- `dioscuri-cloud-gcp-artifacts`
- `dioscuri-cloud-do-gpu-smoke`
- `dioscuri-cloud-aws-mlops`
- `dioscuri-cloud-azure-mlops`
- `dioscuri-cloud-vultr-dev`

Additional recommended examples:
- `dioscuri-cloud-aws-dev-mlops` (if dev/prod separation is required)
- `dioscuri-cloud-gcp-exp-<slug>` (short-lived experiment stack)

## Active workspaces (Issue #46)

Organization: `Dioscuri-Cloud`  
Repository: `rmems/Dioscuri-Cloud`  
Default apply mode: **manual** (no global auto-apply)  
Default execution: **remote**  
Speculative plans: **intended default** (enable in HCP UI; operator confirmation in `experiments/hcp/2026-06-04-vcs-workspace-preflight.md`)

Recommended HCP project/folder grouping (optional in UI):
- `dioscuri-cloud/core` -> `dioscuri-cloud-hcp-core`
- `dioscuri-cloud/providers/ibm` -> `dioscuri-cloud-ibm-dev`
- `dioscuri-cloud/providers/oracle` -> `dioscuri-cloud-oracle-dev`
- `dioscuri-cloud/providers/aws` -> `dioscuri-cloud-aws-training`

| Workspace | Working directory | State boundary | Provider mapping | Variable set strategy |
|---|---|---|---|---|
| `dioscuri-cloud-hcp-core` | `infra/terraform/environments/dev` | HCP control-plane / onboarding metadata only | None | Common variables only |
| `dioscuri-cloud-ibm-dev` | `terraform/envs/ibm-dev` | IBM dev account / resource group | IBM Cloud | Common + IBM (`IBMCLOUD_*`) |
| `dioscuri-cloud-oracle-dev` | `terraform/envs/oracle-dev` | Oracle dev tenancy / compartment | Oracle Cloud | Common + OCI (`OCI_*`) |
| `dioscuri-cloud-aws-training` | `terraform/envs/aws-training` | AWS training account — S3 bucket + IAM primitives for datasets/checkpoints/logs | AWS | Common + AWS (`AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) |

IBM and Oracle workspaces must remain isolated (separate state, separate sensitive variable sets).

Variable names: `docs/hcp/provider-variable-map.md`  
VCS setup: `docs/hcp/vcs-integration.md`

### SAAQ workload note

**IBM and Oracle promo credits are exhausted** (operator confirmed 2026-08-20; see
`docs/credits/inventory.md`). The `ibm-dev` and `oracle-dev` workspaces are
**skeleton-only** — do not apply billable IBM/Oracle resources for SAAQ store/validate.

The original SAAQ artifact store + CPU validation design lives in
`docs/saaq/cloud-store.md`; execution is **deferred** to the AWS training path
(GitHub #47, #52, #53). GPU re-runs (GGUF/safetensors weights) remain separate
deferred issues and are not part of these dev workspaces.

## Deferred workspaces (document only; do not create unless needed)

| Workspace | Intended working directory | Notes |
|---|---|---|
| `dioscuri-cloud-aws-mlops` | TBD under `terraform/` | AWS MLOps primitives |
| `dioscuri-cloud-azure-mlops` | TBD under `terraform/` | Azure MLOps primitives |
| `dioscuri-cloud-gcp-artifacts` | `terraform/envs/gcp-artifacts` | GCP artifacts scaffold exists |
| `dioscuri-cloud-do-gpu-smoke` | TBD | Bounded GPU smoke only |

## Historical / inactive

| Workspace | Working directory | Notes |
|---|---|---|
| `dioscuri-cloud-vultr-dev` | `infra/terraform/environments/vultr-dev` | Vultr credit closeout; do not configure API keys unless a future issue reactivates Vultr |

## When To Create A New Workspace
Create a new workspace when:
- The provider account/subscription/project boundary differs.
- The lifecycle differs:
  - long-lived primitives (artifact buckets, IAM) vs short-lived experiments.
- The failure domain must be isolated:
  - experimenting with new modules/providers that might require state surgery.
- Different variable sets and secrets are required.

Reuse an existing workspace when:
- You are iterating on the same stack with the same lifecycle and the same boundary.
- The resources are tightly coupled and should be planned/applied together.

## Workspace Variables

Use workspace variables for configuration and secrets. Do not commit secrets to git.

Recommended variable categories:

Common (most workspaces):
- `environment` (e.g. `dev`, `prod`, `exp`) if used.
- `owner` (human-readable owner or team label).
- `repo` = `rmems/Dioscuri-Cloud`.
- `cost_center` or `budget_cap_usd` (where applicable).

Provider-specific (examples):
- AWS:
  - `AWS_REGION`
  - `AWS_ACCESS_KEY_ID` (sensitive)
  - `AWS_SECRET_ACCESS_KEY` (sensitive)
  - Prefer OIDC roles later; keep keys temporary.
- Azure:
  - `ARM_SUBSCRIPTION_ID`
  - `ARM_TENANT_ID`
  - `ARM_CLIENT_ID` (sensitive)
  - `ARM_CLIENT_SECRET` (sensitive)
- GCP:
  - `GOOGLE_PROJECT`
  - `GOOGLE_REGION`
  - `GOOGLE_CREDENTIALS` (sensitive JSON) or workload identity later.
- DigitalOcean:
  - `DIGITALOCEAN_TOKEN` (sensitive)
- Vultr:
  - Inactive after the 2026-05-28 credit closeout.
  - Do not add `VULTR_API_KEY` or create Vultr HCP workspace variables unless a future issue explicitly reactivates Vultr.

Conventions:
- Mark all credentials as sensitive variables in HCP.
- Prefer provider-native workload identity / OIDC where possible (tracked in a later issue).
- Rotate/revoke credentials after experiments.
- Treat retired providers as docs-only until reactivated by a new issue.

## Billing model (updated 2026-08-06)

Owner confirms **HashiCorp student / HCP credits (~$500) are still available** (expiry target ~2026-11-10). Organization `Dioscuri-Cloud` may appear as public **Free** (`free_standard`) on the TFC API — free 500 RUM does not automatically burn credits until paid RUM/features or an HCP Flex/Essentials path is active.

| Item | Observed (API / owner) |
|---|---|
| Credit balance | **~$500 still available** (owner) — confirm exact remaining in HCP/TFC **Billing** UI |
| Plan identifier (API) | `free_standard` (public free tier) |
| Free RUM included | 500 managed resources / month |

Practically:
- Use free tier for remote state + VCS speculative plans at $0 RUM cost while under 500 resources.
- To **intentionally spend** the $500: owner must first confirm HCP Billing plan, remaining credit balance, payment method, and a budget alert in a GitHub `[TRAIN]` issue. **Stop** if pay-as-you-go is active without that approval. Then enable paid/Flex billing in HCP UI, grow managed resources via training stacks (`dioscuri-cloud-aws-training`), stay within **$25/experiment** unless the issue approves more.
- GPU compute is billed by cloud providers (AWS/Azure/DO), not HashiCorp.
- Track provider compute in `cost-ledger.md`.

