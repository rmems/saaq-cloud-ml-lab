# SAAQ Cloud Store and Validation

This document defines how SAAQ (Spiking Adaptive Activity Quantization) experiment
artifacts are stored durably in cloud object storage and validated with CPU-only
cloud compute. It is the canonical design for the "explore / validate / store"
goal that connects the local SAAQ pipeline to `Dioscuri-Cloud`.

**No secrets, OCIDs, API keys, model weights, or private local paths belong in git.**
This doc describes structure and contracts only.

See also:
- `docs/hcp/workspaces.md` - HCP workspace boundaries (control plane)
- `docs/hcp/provider-variable-map.md` - provider variable mapping
- `docs/credits/inventory.md` - credit amounts and expirations
- `docs/credits/usage-policy.md` - spend guardrails and teardown rules
- `cost-ledger.md` - billable resource ledger

## Pipeline being stored

```text
corinth-canal (Rust + CUDA, local GPU)         -> produces SAAQ run artifacts
  per-run files:
    summary.json
    latent_telemetry.csv
    tick_telemetry.txt
    run_manifest.json
  campaign rollup:
    index.csv
        |
        v
Surrogate_Viz.jl (Julia, CPU)                  -> validation + discovery
  outputs/<model>/dashboards/*.png + *.md
  outputs/<model>/sr_results/<run_id>/ (SymbolicRegression: pareto_front.csv, sr_manifest.json)
```

grok-ozempic emits a parallel `validation.report.json` bundle that Surrogate_Viz.jl
can also ingest; it follows the same storage contract below.

## What is stored vs what is NOT

In scope for the artifact buckets (small, public-safe, reproducible evidence):
- corinth-canal per-run telemetry: `summary.json`, `latent_telemetry.csv`,
  `tick_telemetry.txt`, `run_manifest.json`
- campaign `index.csv`
- Surrogate_Viz.jl `outputs/` dashboards and `sr_results/`
- grok-ozempic `validation.report.json` / `validation.summary.md`

Explicitly NOT stored in the artifact buckets (handled separately):
- Model weights in any format: **GGUF** (`*.gguf`) and **safetensors**
  (`*.safetensors`, `*.npy` shards). These are multi-GB and are only needed by
  the GPU re-run path (see "Model weights" below), not by CPU validation.
- Any file containing private absolute paths, account identifiers, or secrets.

## Canonical bucket layout

Mirror the local artifact tree so the store is portable across providers.

```text
<bucket>/
  saaq/
    artifacts/
      <campaign>/                         # e.g. issue-40-local
        index.csv
        <model_slug>/
          <telemetry_source>/             # e.g. csv_re4_path_tracing_telemetry | synthetic
            <run_id>/
              summary.json
              latent_telemetry.csv
              tick_telemetry.txt
              run_manifest.json
    outputs/                              # Surrogate_Viz.jl analysis products
      <model>/
        dashboards/<run_id_or_ts>/*.png|*.md
        sr_results/<run_id>/{sr_manifest.json,pareto_front.csv,...}
    manifests/
      run-store-manifest.json             # portable index (see below)
```

The same layout is used on both IBM Cloud Object Storage (COS) and Oracle Object
Storage, so a campaign can be mirrored to either provider without rewriting paths.

## Bucket naming

Follow `docs/credits/usage-policy.md` attribution conventions:

```text
dioscuri-cloud-saaq-<env>-<provider>      # e.g. dioscuri-cloud-saaq-dev-oci
```

The first Oracle bucket already bootstrapped is `dioscuri-cloud-dev-artifacts`
(`us-phoenix-1`, NoPublicAccess); the SAAQ tree lives under its `saaq/` prefix.

Defaults:
- Public access: disabled.
- Versioning: enabled where practical (artifacts are small).
- Force destroy: false.

## Portable run manifest (replaces hardcoded paths)

Today `Surrogate_Viz.jl/data/selected_runs.toml` hardcodes
`/home/raulmc/corinth-canal/artifacts/...` absolute paths, which are not portable
to a cloud VM or container. The cloud store introduces a **bucket-relative**
manifest so the same run set can be resolved locally or from object storage.

`saaq/manifests/run-store-manifest.json` (schema sketch, values illustrative):

```json
{
  "schema": "saaq-run-store/v0",
  "campaign": "issue-40-local",
  "rule": "SaaqV1_5SqrtRate",
  "store_root": "saaq/artifacts/issue-40-local",
  "runs": [
    {
      "id": "<run_id>",
      "model": "<model_slug>",
      "family": "<family>",
      "telemetry_source": "csv_re4_path_tracing_telemetry",
      "condition": "<condition>",
      "repeat_idx": 0,
      "blessed": true,
      "summary": "<model_slug>/<telemetry_source>/<run_id>/summary.json",
      "latent_telemetry": "<model_slug>/<telemetry_source>/<run_id>/latent_telemetry.csv",
      "tick_telemetry": "<model_slug>/<telemetry_source>/<run_id>/tick_telemetry.txt",
      "run_manifest": "<model_slug>/<telemetry_source>/<run_id>/run_manifest.json"
    }
  ]
}
```

Resolution rule: paths are relative to `store_root`. A small env var
(`SAAQ_STORE_ROOT`, local dir or mounted bucket path) lets `import_corinth_runs.jl`
and the bundle ingest scripts read from the same manifest in either environment.

## Sync contract

corinth-canal has no object-storage code (it delegates this to `Dioscuri-Cloud`),
so the sync tool lives here. Direction and idempotency:

- `push`: upload a campaign's `artifacts/<campaign>/` + `index.csv` and the
  Surrogate_Viz `outputs/` tree to `<bucket>/saaq/...`. Skip model weights.
- `pull`: download a campaign + manifest to a local/mounted `SAAQ_STORE_ROOT` for
  CPU validation jobs.
- Object keys are deterministic (the layout above), so re-running `push` is
  idempotent and supports versioning.
- Every billable bucket/operation is recorded in `cost-ledger.md`.

## CPU validation jobs (no model weights required)

These run on Oracle A1.Flex (ARM) or IBM Code Engine without GGUF/safetensors:

corinth-canal (build CPU-only: `--no-default-features`):
- `cargo run --example validate_matrix --no-default-features -- <matrix.toml>`
- `cargo run --example validate_local_saaq --no-default-features -- <matrix.toml> --check-paths`
- `cargo run --example summarize_local_saaq -- <runs-dir>`
- `python scripts/populate_summary.py`

Surrogate_Viz.jl (Julia 1.12, headless: `GKSwstype=100`, `QT_QPA_PLATFORM=offscreen`):
- `julia --project=. import_corinth_runs.jl`
- `julia --project=. SAAQ_latent_discovery.jl`  (SymbolicRegression, CPU, tune `SR_ITERATIONS`)
- `julia --project=. compare_full_lineup_saaq1_5.jl`

## Model weights (GPU re-run path only)

Re-running corinth-canal to produce fresh SAAQ runs needs the model weights and a
GPU; CPU validation does not. Both formats are first-class:

- **GGUF**: `configs/local_gguf_lineup.toml` (gitignored local paths).
- **safetensors**: `configs/safetensors_lineup.toml`,
  `configs/local_safetensors_lineup.template.toml`, `configs/hybrid_moe_lineup.toml`.

Weights are staged to a GPU instance via a separate, deferred path (a dedicated
weights bucket or direct download), tracked in its own issue. They are never
committed and never placed in the SAAQ artifact buckets.

## Provider mapping

**Status (2026-08-20):** IBM and Oracle **promo credits are exhausted** (`docs/credits/inventory.md`).
The IBM/Oracle SAAQ store + CPU validation path is **blocked** until AWS student credits fund a
replacement (see GitHub #47 / #52 / #53 training epic). HCP `ibm-dev` / `oracle-dev` workspaces
remain skeleton-only for historical Terraform layout.

| Concern | Provider | Notes |
|---|---|---|
| Canonical artifact store | ~~Oracle~~ → **AWS S3 (deferred)** | Storage only — see `terraform/envs/aws-training` (GitHub #47). Oracle promo exhausted 2026-06-28; Always Free OCI leftovers are not the SAAQ primary path |
| CPU validation host | ~~Oracle~~ → **undetermined (deferred)** | S3 cannot run the validation commands above — a compute resource (e.g. AWS EC2/Fargate) is not yet planned; track in a follow-on issue before reactivating this path |
| Mirror store + serverless CPU validation jobs | ~~IBM~~ → **deferred** | IBM promo exhausted 2026-06-28; no new COS/Code Engine spend |
| GPU re-run of existing runs / fresh cloud-model runs | AWS (GitHub #53/#54) | weights + GPU; student credits expire 2027-03-15 |
| Control plane (state, plans) | HashiCorp HCP | no provider GPU spend |
