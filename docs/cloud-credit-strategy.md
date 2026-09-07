# Cloud Credit Strategy

This strategy turns the current credit portfolio into explicit provider roles so future experiments can be scheduled without relying on chat-only context.

## Current Credit Position

| Provider | Credit / Trial | Status | Role |
|---|---:|---|---|
| Vultr | `$250` promo credit | Closed out on `2026-05-28`; `$237.31` consumed and `$12.69` expired. | Historical serverless inference sprint only; inactive for near-term execution. |
| IBM Cloud | `$200` cloud credit | **Exhausted 2026-06-28** ($0 remaining; operator confirmed 2026-08-20). | Historical watsonx/COS notes only; not the active training path. |
| IBM watsonx | Free trial | Historical; do not plan new training spend. | Managed AI notes only. |
| Oracle Cloud | `$300` free trial | **Exhausted 2026-06-28** ($0 promo remaining; operator confirmed 2026-08-20). | Document Always Free leftovers vs paid risk; not the active training path. |
| DigitalOcean | Student credits | Active per inventory. | Simple deployments and possible bounded GPU smoke tests. |
| AWS | Student credits | Active per inventory. | Certification-aligned managed ML and storage labs. |
| Azure | Student credits | Active per inventory. | Certification-aligned Azure ML/resource-group labs. |
| GCP | Google AI Pro monthly credit | Monthly. | Tiny inference and metadata-only experiments. |
| HashiCorp | Student / HCP `$500` | **Still available** (owner confirmed 2026-08-06; expires ~2026-11-10). Org may show `free_standard` on TFC API. | Control plane: VCS plans, remote state, policy/run-task labs; burn credits only after free 500 RUM or when paid features are intentionally enabled. |

## Provider Roles (training setup)

| Role | Primary Provider | Backup Provider | Notes |
|---|---|---|---|
| Training artifacts (S3 layout) | AWS S3 | Azure Blob | See `docs/training/artifact-layout.md` |
| GPU training nodes | AWS | DigitalOcean | Bounded smokes; smallest SKU |
| Managed training jobs | AWS SageMaker | Azure ML | Tiny jobs first |
| IaC control plane | HashiCorp HCP Terraform | Local Terraform + GH Actions validate | Free 500 RUM first |
| Certification / misc labs | AWS, Azure | DO, GCP | Not the training critical path |

## Provider Roles (historical / non-training)

| Role | Primary Provider | Backup Provider | Notes |
|---|---|---|---|
| Managed AI / agent prototypes | IBM watsonx | GCP / Vertex AI | Keep payloads small and record service limits. |
| Always-on lightweight services | Oracle Cloud | DigitalOcean | Favor free-tier/low-cost instances with explicit teardown or retained-resource notes. |
| Certification labs | AWS, Azure | IBM Cloud | Align labs to IAM, storage, managed ML, and budget controls. |
| Artifact storage | IBM COS, Oracle Object Storage, AWS S3 | Azure Blob, DO Spaces | Implement only after `docs/artifact-storage-plan.md` is mapped to provider resources. |
| GPU or inference bursts | DigitalOcean, AWS, Azure | IBM/GCP managed services where credits fit | **Training:** AWS primary for GPU/SageMaker; IBM/Oracle trials expired 2026-06-28. |
| IaC control plane | HashiCorp HCP Terraform (+ $500 credits) | Local Terraform + GH Actions validate | Free tier first (500 RUM); credits for paid RUM/features before ~2026-11-10. |

## Scheduling Rules

1. Use expiring credits first only when the run has a bounded queue and teardown plan.
2. Record every billable run in `cost-ledger.md`.
3. Prefer the smallest provider-native experiment that produces a durable repo artifact.
4. Avoid full-model Grok-1 work in this repo; bounded cloud **training setup** smokes are in scope per `[TRAIN]` issues.
5. Do not upload, configure, or commit Vultr API material unless a future issue explicitly reactivates Vultr.
6. Do not plan new IBM or Oracle **training** spend — trials expired 2026-06-28; use AWS/Azure student credits.
