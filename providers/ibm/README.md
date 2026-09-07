# IBM Cloud And watsonx Onboarding

**Historical / reference-only.** IBM Cloud credit is exhausted (see below) — do not plan new billable IBM spend. The watsonx/research-agent/synthetic-data/object-storage assignments and experiment ideas below document what this account *was* used for and remain for reference; they are not active execution guidance. The AWS training path (GitHub #47/#52/#53) is the active path for equivalent work.

## Credit And Trial Status

| Item | Status | Notes |
|---|---|---|
| IBM Cloud credit | **Exhausted** (was `$200`, expired 2026-06-28) | Operator confirmed **$0 remaining** (2026-08-20). Do not plan new billable IBM spend. |
| watsonx free trial | **Inactive for new spend** | Historical experiments only; verify console before any reactivation. |

## Account And Region Notes

- Use the IBM Cloud console for account/resource-group setup.
- Select one initial region and keep early experiments in that region for easier teardown.
- Use a dedicated resource group such as `dioscuri-cloud`.
- Do not commit API keys, service credential names, account IDs, billing screenshots, or private resource IDs.
- Store credentials only in local environment variables, HCP Terraform sensitive variables, or provider-managed secret stores.

## Useful Services

| Service | Dioscuri-Cloud Use |
|---|---|
| watsonx.ai | Managed model evaluation, prompt tests, synthetic data, and research-agent prototypes. |
| watsonx Orchestrate / agent tooling | Agent workflow exploration if accessible in the trial. |
| Code Engine | Short-lived container jobs and lightweight services. |
| Cloud Object Storage | Experiment manifests, telemetry samples, and public-safe reports. |
| Kubernetes / OpenShift options | Later container orchestration labs only after cost guardrails are clear. |
| Vector / retrieval services | RAG or SAAQ assistant prototypes if available under the account/trial. |

## First Experiment Ideas (historical — not active; credit exhausted)

| Idea | Output Artifact | Guardrail |
|---|---|---|
| Research-agent prototype | `experiments/ibm/<date>-research-agent.md` | Keep prompts and outputs public-safe. |
| Synthetic data pipeline | `experiments/ibm/<date>-synthetic-data.md` | No sensitive/private source data. |
| SAAQ/RAG assistant | `experiments/ibm/<date>-saaq-rag-assistant.md` | Reference downstream repos instead of duplicating SAAQ internals. |
| Model evaluation harness | `experiments/ibm/<date>-model-eval.md` | Cap runtime and token spend before execution. |

## Known Constraints To Check

- Some watsonx or agent services may require business-email or account eligibility checks.
- Region availability may differ between IBM Cloud services and watsonx services.
- Free-trial quotas should be verified before any run that could incur overage.

## Related Files

- Bootstrap runbook: `providers/ibm/bootstrap.md`
- Provider strategy: `docs/cloud-credit-strategy.md`
- Artifact plan: `docs/artifact-storage-plan.md`
- Cost ledger: `cost-ledger.md`
