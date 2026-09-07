# Cloud AI training setup (epic index)

**Updated:** 2026-08-19. Dioscuri-Cloud is now scoped to **standing up cloud AI model training** (storage, GPU/managed jobs, cost/teardown, HCP control plane). Bounded fine-tune/SFT smokes are in scope; from-scratch large pretraining is not.

## Issue map (GitHub ↔ Linear)

| Order | GitHub | Linear | Title |
|---:|---|---|---|
| 1 | [#57](https://github.com/rmems/Dioscuri-Cloud/issues/57) | RM-78 | Training credit map, budgets, and teardown policy |
| 2 | [#52](https://github.com/rmems/Dioscuri-Cloud/issues/52) | RM-75 | Artifact contract for checkpoints, logs, and metrics |
| 3 | [#47](https://github.com/rmems/Dioscuri-Cloud/issues/47) | RM-72 | Checkpoint and dataset object storage (S3 primary) |
| 4 | [#61](https://github.com/rmems/Dioscuri-Cloud/issues/61) | RM-81 | CUDA training image + Terraform module |
| 5 | [#62](https://github.com/rmems/Dioscuri-Cloud/issues/62) | RM-82 | One-script bootstrap for a training environment |
| 6 | [#53](https://github.com/rmems/Dioscuri-Cloud/issues/53) | RM-76 | Bounded GPU training node on AWS |
| 7 | [#54](https://github.com/rmems/Dioscuri-Cloud/issues/54) | RM-77 | Managed training job (SageMaker, Azure ML backup) |
| 8 | [#50](https://github.com/rmems/Dioscuri-Cloud/issues/50) | RM-74 | Training-run metadata ingest |
| 9 | [#60](https://github.com/rmems/Dioscuri-Cloud/issues/60) | RM-80 | Experiment tracking for training runs |
| 10 | [#59](https://github.com/rmems/Dioscuri-Cloud/issues/59) | RM-79 | First bounded training smoke (tiny job + teardown) |

There is **no RM-73** in this epic. Linear IDs are not a contiguous `RM-72`–`RM-82` range.

Canonical GitHub bodies (if GitHub still shows stale text): [`docs/issues/`](issues/README.md). Apply with `scripts/apply-github-issue-overrides.sh`.

GitLab secondary CI: [issue #1](https://gitlab.com/rmems/Dioscuri-Cloud/-/issues/1) — see [`docs/gitlab/issue-1-training-ci.md`](gitlab/issue-1-training-ci.md).

## Dependency flow

```text
#57 policy → #52 artifact contract → #47 S3
#57 → #61 image/module → #53 GPU and #54 SageMaker
#52 → #50 metadata, #60 tracking
#53 or #54 + #50 + #60 + optional #62 → #59 integration smoke
```

## Active credits (training)

| Provider | Expires | Role |
|---|---|---|
| AWS $200 | 2027-03-15 | Primary compute + S3 |
| Azure $100 | 2027-02-12 | Backup managed training |
| DigitalOcean $205 | 2027-04-28 | Optional GPU check |
| HashiCorp ~$500 | ~2026-11-10 | HCP Terraform (not GPU) |
| GCP $10/mo | Monthly | Planning only |

IBM and Oracle trial credits expired 2026-06-28 — not the training execution path. See `docs/credits/inventory.md`.

## Bootstrap checklist (Issue #62)

Before launching any real training compute, run `scripts/training-bootstrap.sh`
(`docs/training/bootstrap.md`) and confirm:

- [ ] HCP Terraform Cloud auth present (`terraform login` or `TF_TOKEN_app_terraform_io`)
- [ ] `aws sts get-caller-identity` succeeds for the training account
- [ ] `TRAINING_BUCKET_NAME`'s `training/` prefix is listable (bucket applied per #47)
- [ ] Training image builds locally or pulls from ECR (#61)
- [ ] Optional: GPU node `nvidia-smi` or SageMaker job dry-run succeeds (#53/#54)

The script fails closed on the first unmet item and prints which step
blocked — an operator should never need to guess credential layout.

## Guardrails

- GitHub issue required before spend (`docs/credits/usage-policy.md`).
- `cost-ledger.md` before billable apply.
- Default AWS cap $25/experiment unless issue documents approval.
- No secrets or model weights in git.
