# Azure OIDC authentication preflight

Proves GitHub Actions -> Azure OIDC authentication for Dioscuri-managed
training infrastructure, without deploying or mutating any Azure resource
(GitHub #66). This is a prerequisite gate: the successful preflight run must
be linked from the bounded Azure training-job issue before any real Azure
execution (e.g. an Azure ML training job) is authorized.

Workflow: `.github/workflows/azure-oidc-preflight.yml` (`workflow_dispatch`
only — never triggered by push or pull_request).

## What it does

1. Exchanges the GitHub Actions OIDC token for an Azure access token via
   `azure/login`, using a federated credential (no client secret, no
   long-lived Azure credential stored in GitHub).
2. Runs `az account show` — a single read-only identity/subscription
   inspection call.
3. Writes a public-safe Markdown report (`preflight-report.md`) with the
   repository commit, workflow run ID, and pass/fail status. Subscription
   ID, tenant ID, and any other account identifiers are **never** included
   in the report or echoed to a public log.
4. Uploads the report as a workflow artifact (90-day retention).

The workflow has no path to create, update, or delete any Azure resource —
there is no step capable of doing so, and workflow-level `permissions` grant
only `id-token: write` (job level) and `contents: read`.

## Required setup (operator, one-time)

### 1. Microsoft Entra app registration + federated credential

1. Create an Entra app registration (or reuse an existing one scoped to this
   purpose only — do not reuse a broad, pre-existing service principal).
2. Add a **federated credential** on that app registration for GitHub
   Actions:
   - Issuer: `https://token.actions.githubusercontent.com`
   - Entity type: **Environment**
   - Repository: `rmems/Dioscuri-Cloud`
   - Environment name: `azure-oidc-preflight` (must match the workflow's
     `environment:` key)
3. Assign the app registration the **Reader** role (or narrower) on the
   target subscription — this preflight only calls `az account show`, so no
   write/contribute role is needed. Do not assign Contributor/Owner for this
   preflight identity.

### 2. GitHub environment

1. Create a GitHub **environment** named `azure-oidc-preflight` in this
   repository's settings (Settings -> Environments).
2. Add environment secrets (not repository-wide secrets, to keep them
   scoped to this one workflow's environment):
   - `AZURE_CLIENT_ID` — the app registration's client (application) ID
   - `AZURE_TENANT_ID` — the Entra tenant ID
   - `AZURE_SUBSCRIPTION_ID` — the target subscription ID
3. Optionally add required reviewers on the environment for an extra manual
   gate before the workflow can run.

None of these three values are Azure secrets in the traditional sense (no
client secret/certificate is used — OIDC federation replaces that), but they
are still stored as environment secrets rather than plain repository
variables to keep them out of workflow logs by default and to scope them to
this one environment.

## Running the preflight

1. Go to Actions -> `azure-oidc-preflight` -> **Run workflow** (manual
   dispatch only; there is no automatic trigger).
2. Wait for the `preflight` job to complete.
3. Open the job's `Read-only identity/subscription inspection + report` step
   log, or download the `azure-oidc-preflight-report` artifact, to confirm
   `Status: PASS`.
4. Link the successful run (its URL) in the Azure training-job issue before
   requesting authorization to run real Azure ML training work.

## Failure diagnostics

| Symptom | Likely cause |
|---|---|
| `azure/login` step fails with a token-exchange error | Federated credential's issuer/entity/environment name doesn't match this repo+environment exactly, or the environment secrets are missing/misnamed |
| `az account show` fails with an authorization error | The app registration has no role assignment on the target subscription, or the wrong `AZURE_SUBSCRIPTION_ID` was configured |
| Workflow doesn't appear to have `id-token: write` | Confirm the job-level `permissions:` block in the workflow wasn't edited away — this preflight requires it to request an OIDC token at all |
| Report shows `Status: FAIL` | `az account show` failed after a successful login — check subscription access/role assignment; the report intentionally omits identifiers, so check the (private) job log for the underlying Azure CLI error |

## Non-goals

- No Azure ML, compute, storage, networking, or registry provisioning —
  that's separate, explicitly authorized infrastructure work.
- No Agoge training job.
- No duplicating Terraform or provider-auth workflows inside this preflight.
