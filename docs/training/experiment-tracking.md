# Experiment tracking for training runs

Tracks training metrics and run history in the artifact bucket itself
(GitHub #60) — not a shared RAG vector database, and not a paid managed
experiment-tracking platform unless separately cap-approved in an issue.

The contract this relies on is defined in `docs/training/artifact-layout.md`
("Metrics and run index" section): every run writes
`training/logs/<run_id>/metrics.json` and a run manifest at
`training/manifests/<run_id>.json`; buckets may additionally maintain
`training/manifests/index.json` as a lightweight cross-run index.

Issue #60's scope allows a run to produce "metrics.json **or** TensorBoard
event files." This doc's comparison workflow deliberately requires the
small structured `metrics.json` specifically — parsing TensorBoard's binary
event format for a two-line loss/wall-time diff would defeat "comparable
from stored artifacts alone." A run that only emits TensorBoard events
under `training/logs/<run_id>/events/` remains valid per the artifact
layout, but isn't comparable via this doc's workflow until it also writes
a `metrics.json` summary (even a minimal one, generated from the same
event data).

## Comparing two training smokes

Two runs can be compared **from stored artifacts alone** — no external
tracker required.

1. Fetch both run manifests:
   ```bash
   aws s3 cp s3://<bucket>/training/manifests/<run_id_a>.json .
   aws s3 cp s3://<bucket>/training/manifests/<run_id_b>.json .
   ```
2. Fetch both metrics files:
   ```bash
   aws s3 cp s3://<bucket>/training/logs/<run_id_a>/metrics.json metrics_a.json
   aws s3 cp s3://<bucket>/training/logs/<run_id_b>/metrics.json metrics_b.json
   ```
3. Compare the fields that matter for a smoke-to-smoke comparison:

   | Dimension | Manifest field | Metrics field |
   |---|---|---|
   | Step loss | — | `final_loss` (or last entry in `steps`) |
   | Wall time | — | `wall_time_seconds` |
   | Cost | `estimated_cost_usd` / `actual_cost_usd` | — |
   | Steps completed | `steps_completed` | `final_step` |
   | Trainer/base model | `trainer`, `base_model` | — |

   A one-line `jq` comparison, handling `final_loss: null` (permitted by the
   schema, e.g. for trainers that don't report a scalar loss) rather than
   erroring on the subtraction:
   ```bash
   jq -s '.[0].final_loss as $a | .[1].final_loss as $b |
     if ($a == null or $b == null)
     then {a: $a, b: $b, delta: "not comparable (null final_loss)"}
     else {a: $a, b: $b, delta: ($b - $a)} end' \
     metrics_a.json metrics_b.json
   ```
   If `final_loss` is null but a `steps` array is present, use the last
   entry's `loss` instead (`.steps[-1].loss`) in place of `.final_loss`
   above.

If a bucket maintains `training/manifests/index.json`, skip steps 1–2 and
query it directly — it already carries `trainer`, `base_model`,
`final_loss`, `wall_time_seconds`, `steps_completed`, and both cost fields
per run.

## What "comparable" means here

This is a smoke-to-smoke sanity comparison (did the second run improve on
the first, roughly how much did it cost, how long did it take) — not
statistical benchmarking. If you need repeated runs, parameter sweeps, or
profiling, that's a "real experiment" per
`docs/runbooks/gpu-smoke-test-readiness.md` and should be scoped as its own
issue with explicit cost and teardown expectations, not folded into this
lightweight tracking path.

## Non-goals

- No shared RAG vector database or IDE-tool integration.
- No paid managed experiment-tracking platform (e.g. Weights & Biases,
  Neptune) unless cap-approved in a specific issue per
  `docs/credits/usage-policy.md`.
