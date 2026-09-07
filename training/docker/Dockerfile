# Pinned CUDA runtime base — bump deliberately and update
# providers/aws/training-image-runbook.md when you do. See
# docs/runbooks/gpu-smoke-test-readiness.md for the readiness gates a GPU
# run using this image must satisfy before any cloud spend.
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1

# Use Ubuntu 22.04's default python3 (3.10) rather than pinning python3.11 —
# jammy's default apt sources don't carry python3.11 without adding the
# deadsnakes PPA, which would make this build fail out of the box.
#
# Base OS packages intentionally track the latest security patches available
# for the pinned base image tag/digest above; the base image tag is the
# reproducibility control here, not individual apt package versions.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Torch build must track the CUDA runtime above (cu124). Bump both together.
RUN python3 -m pip install --no-cache-dir \
        torch==2.4.1 --index-url https://download.pytorch.org/whl/cu124 \
    && python3 -m pip install --no-cache-dir \
        boto3==1.35.36 \
        numpy==1.26.4

RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin trainer

WORKDIR /opt/training
COPY entrypoint.sh /opt/training/entrypoint.sh
RUN chmod +x /opt/training/entrypoint.sh && chown -R trainer:trainer /opt/training

# No dataset/checkpoint/weight files are baked into this image — training
# code and datasets are staged at runtime from S3 (docs/training/artifact-layout.md).

USER 1000

ENTRYPOINT ["/opt/training/entrypoint.sh"]
CMD ["--help"]
