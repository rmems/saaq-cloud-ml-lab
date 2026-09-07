# HCP status + HashiCorp credit inventory (2026-08-06)

Public-safe status after correcting an earlier false closeout.

## Credits (corrected)

| Item | Status |
|---|---|
| Student / HCP **~$500** | **Still available** (owner confirmed 2026-08-06; do not treat as expired) |
| Target expiry | ~**2026-11-10** (verify in portal) |
| Org plan (TFC API) | `free_standard` (public free tier) — free 500 RUM does not by itself consume credits |
| Free RUM limit | 500 managed resources / month |
| Free applies (snapshot) | 50 remaining |
| Concurrent runs | 1 |
| Current RUM under management | **0** |

Earlier draft that called credits “exhausted” was **wrong** and has been reverted in inventory/strategy docs.

## How credits can actually burn

Free-tier RUM (≤500) is $0. Credits typically burn when:

1. HCP billing is on a **paid / Flex / Essentials** path and managed resources (or HCP services) are metered, **or**
2. You use other HCP products (e.g. Vault Secrets) that consume platform credits.

**Operator check:** open HCP / TFC **Billing / Credits** UI and record exact remaining balance + whether credits are “applied” vs “pending activation”.

## Workspaces (API)

| Workspace | Working directory | VCS linked | Resource count |
|---|---|---|---:|
| `dioscuri-cloud-hcp-core` | `infra/terraform/environments/dev` | no | 0 |
| `dioscuri-cloud-ibm-dev` | `terraform/envs/ibm-dev` | no | 0 |
| `dioscuri-cloud-oracle-dev` | `terraform/envs/oracle-dev` | no | 0 |

OAuth clients (GitHub VCS): **0** — install HashiCorp GitHub app before speculative plans work.

## Tooling

- **Terraform Cloud API**: `terraform login` token works.
- **`hcp` CLI** v0.10.0: HCP Platform (Vault Secrets, projects, IAM, Waypoint) — re-auth with `hcp auth login` if refresh token is invalid.
- **Terraform MCP** (`hashicorp/terraform-mcp-server:1.2.0`): agent registry + workspace tools (does not spend credits by itself).

## Operating model (with credits still live)

1. Unblock VCS + speculative plans ($0 process value).
2. Keep day-to-day under free 500 RUM when possible.
3. Intentionally enable paid path only for bounded labs that produce durable artifacts (policies, multi-workspace stacks for SAAQ store, agoge training nodes metadata) and stay within **$25/experiment** unless approved in a GitHub issue (`docs/credits/usage-policy.md` — GitHub is canonical for spend tracking; a Linear mirror does not replace it), with the run recorded in `cost-ledger.md`.
4. Provider GPU/compute still uses AWS/Azure/DO (etc.) student credits — separate from HashiCorp.
