#!/usr/bin/env bash
set -euo pipefail

echo "== training image dry-run check =="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || echo "nvidia-smi present but failed (no GPU attached to this container run?)"
else
  echo "nvidia-smi not found in PATH — GPU driver not mounted into this container."
fi

if [ "${1:-}" = "--help" ] || [ "$#" -eq 0 ]; then
  cat <<'EOF'
Usage: docker run ... <training-entrypoint-args>

This image runs a GPU dry-run check (nvidia-smi) on start, then execs the
given command. Pass your training script/module as arguments, e.g.:

  docker run --gpus all <image> python3 train.py --steps 10

See providers/aws/training-image-runbook.md for build/push and
EC2/SageMaker usage.
EOF
  exit 0
fi

exec "$@"
