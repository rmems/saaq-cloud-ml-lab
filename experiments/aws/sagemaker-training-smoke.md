# AWS SageMaker Training Smoke — Run Record

Date: `2026-09-07`

Run ID: `TBD` (assigned at actual launch)

Provider: `aws`

Git commit SHA: `TBD` (assigned at actual launch)

GitHub issue: `rmems/Dioscuri-Cloud#54`

Linear issue: `RM-77`

## Status: BLOCKED — prerequisites not yet applied

This is a readiness record, not a completed run. The training-job launch
documented in `providers/aws/training-image-runbook.md` and
`providers/aws/managed-ml-smoke-test.md` ("Training Job Path") has **not**
been executed, because its prerequisites are code-complete but not yet
live:

| Prerequisite | Status |
|---|---|
| S3 training bucket (`terraform/envs/aws-training`, #47) | Terraform written and reviewed (PR #67), **not yet applied** — no live bucket |
| SageMaker execution role + ECR repo (`terraform/modules/training_execution`, #61) | Terraform written and reviewed (PR #68), **not yet applied** — no live role/repo |
| Training image pushed to ECR | Dockerfile written and reviewed (PR #68), **not yet built/pushed** — no image to reference |
| Tiny training dataset staged in S3 | Not staged — no bucket exists yet to stage it in |

Launching a real `aws sagemaker create-training-job` today would fail
immediately (no execution role ARN, no ECR image, no bucket) — there is no
value in attempting it before #47/#61 land, and doing so risks a confusing,
uninformative failure rather than a real go/no-go signal.

## GPU Smoke-Test Readiness Checklist (docs/runbooks/gpu-smoke-test-readiness.md)

- [ ] Local baseline completed — **not yet done.** `training/docker/README.md` only documents `--help`/dry-run *behavior*; the readiness checklist requires the exact code path to actually be exercised locally with real output, which hasn't happened. Do not treat the paid SageMaker launch as the first real exercise of this container.
- [ ] No-GPU object storage smoke completed — blocked on #47 bucket existing
- [x] Cost estimate recorded (below)
- [ ] Provider / region / SKU selected — provider (`aws`) and SKU (`ml.g4dn.xlarge`) are chosen, but **region is still `TBD`** (see Planned run below); leave this unchecked until a concrete region is recorded, since the region gates whether the bucket/ECR image/requested capacity actually line up
- [ ] Quota / availability checked — requires a real AWS account session against the training account
- [ ] Terraform plan reviewed — PRs #67/#68 pass `terraform validate`/`terraform test` in CI, which is not the same as a reviewed `terraform plan` against real HCP state; leave unchecked until a real plan exists
- [ ] Artifact path selected — the *scheme* is fixed (`s3://<bucket>/training/checkpoints/<run_id>/` per `docs/training/artifact-layout.md`), but both `<bucket>` and `<run_id>` are still placeholders; leave unchecked until a concrete bucket and a concrete, unique `run_id` are recorded, so a later launch can't accidentally reuse a prefix and mix `step_<n>` data or overwrite `latest.json`
- [x] Experiment manifest template prepared — run-specific draft below (not just a link to the generic schema), with known fields filled in and the rest marked `TBD`
- [x] Teardown checklist linked (`docs/runbooks/teardown-checklist.md`) — see Teardown section below for why a SageMaker job's teardown looks different from a deletable resource
- [ ] Max runtime / cost cap defined — proposed below, needs operator sign-off before launch

**Review by 2026-10-07** (or sooner, whenever #67/#68 merge and are applied) — re-check this record and its blockers rather than letting it go stale.

## Planned run

- Provider: `aws`
- Region: `TBD` — must match the region the `dioscuri-cloud-aws-training` bucket and ECR repository are created in (not yet chosen; #47/#61 have no default region baked in, by design — see `docs/hcp/provider-variable-map.md`)
- Instance type: `ml.g4dn.xlarge` (smallest common single-GPU SageMaker training instance type; matches `terraform/modules/training_node`'s EC2 default for consistency)
- Max runtime: `1800` seconds (30 minutes) — generous upper bound for a "tiny job"; actual smoke should complete in minutes
- Max cost cap (USD): `$25` (default AWS cap per `docs/credits/inventory.md`; this smoke should cost well under $1 for a `ml.g4dn.xlarge` running a few minutes)
- Artifact path: `s3://<bucket>/training/checkpoints/<run_id>/`

## Draft run manifest

Per `docs/schemas/experiment-manifest.md` training fields — known values
filled in now, the rest marked `TBD` until launch. This is the actual
manifest shape this run will emit to
`s3://<bucket>/training/manifests/<run_id>.json`, not just a link to the
schema doc:

```json
{
  "run_id": "TBD",
  "job_type": "training",
  "git_commit_sha": "TBD",
  "repo": "rmems/Dioscuri-Cloud",
  "github_issue": "rmems/Dioscuri-Cloud#54",
  "base_model": "TBD",
  "model_slug": "TBD",
  "trainer": "TBD",
  "steps_configured": "TBD",
  "steps_completed": null,
  "telemetry_source": "synthetic",
  "provider": "aws",
  "region": "TBD",
  "instance_type": "ml.g4dn.xlarge",
  "gpu_type": "NVIDIA T4",
  "dataset_uri": "TBD",
  "checkpoint_uri": "TBD",
  "start_time_utc": null,
  "end_time_utc": null,
  "estimated_cost_usd": 1.0,
  "actual_cost_usd": null,
  "artifact_uris": ["TBD"],
  "teardown_confirmed": false,
  "notes": "Readiness-record draft; not yet launched. See experiments/aws/sagemaker-training-smoke.md."
}
```

## Cost

Estimated cost USD: `< 1` (a few minutes of `ml.g4dn.xlarge`, well under the $25 default cap)

Actual cost USD: `TBD` (not run)

Cost-ledger reference: `cost-ledger.md` — AWS SageMaker training smoke row (est. only, not yet applied)

## Teardown

Resources created: `none` (not run)

Teardown evidence: `N/A` — nothing to tear down yet. Note for the eventual
real run: SageMaker training jobs are not deleted like a compute
instance — they run to a terminal state (`Completed`/`Failed`/`Stopped`).
"Teardown evidence" for this run type is the job's terminal
`DescribeTrainingJob` status, not a delete confirmation.

## Notes

Filed as a readiness record rather than skipped entirely so the blocker is
explicit and trackable: once PR #67 and PR #68 are merged and applied
(HCP workspace created, bucket live, execution role + ECR repo live, image
pushed), this file should be updated in place with the real `run_id`,
commit SHA, actual launch command used, and results — not replaced with a
new file — to keep the readiness-to-completion history in one place.
