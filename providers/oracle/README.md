# Oracle Cloud Onboarding

Oracle Cloud is assigned to persistent free-tier services, lightweight Rust deployments, telemetry ingestion, object storage, and vector/RAG backend exploration for Dioscuri-Cloud.

## Trial Status

| Item | Status | Notes |
|---|---|---|
| Oracle Cloud free trial | **Exhausted** (was `$300`, expired 2026-06-28) | Operator confirmed **$0 promo remaining** (2026-08-20). Always Free tier may still apply to retained resources — review monthly for paid risk. |

## Account And Region Notes

- Pick one home region for early labs and record it in future run records.
- Use compartments, tags, and clear resource names for teardown attribution.
- Do not commit tenancy OCIDs, private account IDs, API keys, config files, fingerprints, local paths, or billing screenshots.
- Store provider config outside the repo and use environment variables or secret stores for automation.

## Useful Services

| Service | Dioscuri-Cloud Use |
|---|---|
| Compute instances | Persistent MCP server, lightweight Rust API, or telemetry worker. |
| ARM/free-tier options | Low-cost always-on experiments if capacity is available. |
| Object Storage | Experiment manifests, telemetry batches, and report archives. |
| Container services | Later deployment labs after compute/networking basics are documented. |
| Database/vector/RAG services | Retrieval backend or telemetry index if trial limits permit. |

## First Experiment Ideas

| Idea | Output Artifact | Guardrail |
|---|---|---|
| Always-on MCP server | `experiments/oracle/<date>-mcp-server.md` | Record retained-resource cost and teardown/review date. |
| Telemetry ingestion API | `experiments/oracle/<date>-telemetry-api.md` | Use small payloads and explicit retention. |
| Vector DB / RAG backend | `experiments/oracle/<date>-rag-backend.md` | No private data or model weights. |
| Lightweight Rust service deployment | `experiments/oracle/<date>-rust-service.md` | Use smallest viable compute and firewall scope. |

## Quota And Capacity Checks

Record the following before any paid or retained resource is created:

- Region and availability domain.
- Compute shape availability.
- Free-tier or trial eligibility.
- Public IP, block volume, object storage, and load balancer quotas.
- Expected monthly cost if a resource remains online.

## Related Files

- Bootstrap runbook: `providers/oracle/bootstrap.md`
- HCP workspace map: `docs/hcp/workspaces.md`
- Provider strategy: `docs/cloud-credit-strategy.md`
- Artifact plan: `docs/artifact-storage-plan.md`
- Cost ledger: `cost-ledger.md`
