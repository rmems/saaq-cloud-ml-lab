# Training artifact layout

Canonical object-storage paths for cloud AI **training** runs. Implementations: GitHub #47 (bucket), #52 (contract), #53/#54 (jobs).

**Do not store staged base-model weights** (downloaded GGUF/safetensors/HF snapshots used as input) in these buckets. Stage those at runtime via a separate path. **Do store generated run checkpoints** under `training/checkpoints/<run_id>/` (optimizer/model state produced by the job). No secrets in git.

## Bucket prefix

```text
<training-bucket>/
  training/
    datasets/
      <dataset_slug>/
        manifest.json
        shards/...
    checkpoints/
      <run_id>/
        step_<n>/...
        latest.json          # pointer: {"checkpoint_prefix": "training/checkpoints/<run_id>/step_<n>/"}
    logs/
      <run_id>/
        metrics.json
        events/          # optional TensorBoard
    manifests/
      <run_id>.json
      index.json         # optional append-only run index
```

`latest.json` is an object-store pointer, not a filesystem symlink. S3 and Azure Blob have keys, not `ln -s`. `checkpoint_uri` in the run manifest should be the prefix of the latest completed step (the same value as `checkpoint_prefix` in `latest.json`).

## Manifest

See `docs/schemas/experiment-manifest.md` (training fields) and `examples/training-run-manifest.synthetic.json`.

## Metrics and run index (GitHub #60)

`training/logs/<run_id>/metrics.json` — written by the training job itself
(or the tracking step immediately after). Required top-level fields:

| Field | Type | Description |
|---|---|---|
| `run_id` | string | Same value as the run manifest's `run_id`. |
| `final_step` | integer | Last completed step (matches `steps_completed` in the manifest). |
| `final_loss` | number | Loss at `final_step`. `null` if not applicable to the trainer. |
| `wall_time_seconds` | number | Total wall-clock training time. |

Optional: a `steps` array of `{"step": <n>, "loss": <n>, "wall_time_seconds": <n>}`
per-step records, and/or `training/logs/<run_id>/events/` for TensorBoard
event files when the trainer emits them. `metrics.json` alone must be
sufficient to compare runs — the `events/` directory is for deeper
inspection, not required for comparison.

`training/manifests/index.json` (optional, per-bucket) — a lightweight
append-only index so two runs can be compared without listing every
manifest individually:

```json
{
  "runs": [
    {
      "run_id": "synthetic-smoke-2026-08-19",
      "job_type": "training",
      "provider": "aws",
      "instance_type": "g4dn.xlarge",
      "trainer": "synthetic-trainer",
      "base_model": "synthetic/example-7b",
      "steps_completed": 10,
      "final_loss": 1.234,
      "wall_time_seconds": 300,
      "estimated_cost_usd": 1.0,
      "actual_cost_usd": null,
      "manifest_uri": "s3://<bucket>/training/manifests/synthetic-smoke-2026-08-19.json",
      "checkpoint_uri": "s3://<bucket>/training/checkpoints/synthetic-smoke-2026-08-19/step_10/",
      "created_at": "2026-08-19T12:05:00Z"
    }
  ]
}
```

**Deduplication rule:** `run_id` is unique within `index.json`. A retry or
re-run that reuses the same `run_id` **replaces** the existing entry in
place — never append a second entry for the same `run_id`. The file is
append-only only in the sense that a genuinely **new** `run_id` gets a new
entry; writers must read-modify-write (not blind-append) to enforce this.

**Concurrency caveat:** a plain read-modify-write to a shared `index.json`
races if two runs finish close together — the second writer can overwrite
the first's new entry with a copy that doesn't include it. For the current
one-smoke-at-a-time execution model (`docs/runbooks/gpu-smoke-test-readiness.md`)
this is a low-probability, low-stakes gap: `training/manifests/<run_id>.json`
remains the source of truth per run, and `index.json` can always be
rebuilt from those. If concurrent writers become common, use S3 conditional
writes (`If-Match` on the object's ETag, retry-on-conflict) rather than a
bare read-modify-write.

See `docs/training/experiment-tracking.md` for how to use these to compare
two runs.

## Provider neutrality

Use the same key layout on AWS S3 (primary), Azure Blob (backup), and other backends. URIs in manifests use `s3://` or `https://` forms without account IDs in git.
