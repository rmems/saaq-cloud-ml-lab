#!/usr/bin/env bash
# One-script bootstrap preflight for the AWS training environment (Issue #62).
# Public-safe: never reads or prints secret values. Fails closed — each
# numbered check must pass before the next runs. See docs/training/bootstrap.md
# for required environment variables and where credentials live.
#
# Steps 1-4 are read-only. Step 5's GPU path (TRAINING_GPU_INSTANCE_ID) is NOT
# read-only: it dispatches a real command via ssm:SendCommand (a write IAM
# action) and waits for it to finish. See docs/training/bootstrap.md.
set -euo pipefail

log() { printf '\n== %s ==\n' "$1"; }
fail() {
  printf 'BLOCKED: %s\n' "$1" >&2
  exit 1
}

# 1. HCP: confirm Terraform Cloud auth is configured AND can actually reach
#    org Dioscuri-Cloud, workspace dioscuri-cloud-aws-training
#    (terraform/envs/aws-training) — not just that a token/file exists.
log "1/5 HCP Terraform authentication"
command -v terraform >/dev/null 2>&1 || fail "terraform CLI not found. Install Terraform first."
command -v curl >/dev/null 2>&1 || fail "curl not found. Install curl first."
command -v jq >/dev/null 2>&1 || fail "jq not found. Install jq first."

HCP_ORG="${HCP_ORG:-Dioscuri-Cloud}"
HCP_WORKSPACE="${HCP_WORKSPACE:-dioscuri-cloud-aws-training}"
HCP_API_BASE="${TF_API_BASE:-https://app.terraform.io/api/v2}"

if [ -z "${TF_TOKEN_app_terraform_io:-}" ] && [ -f "${HOME}/.terraform.d/credentials.tfrc.json" ]; then
  TF_TOKEN_app_terraform_io="$(jq -r '.credentials["app.terraform.io"].token // empty' "${HOME}/.terraform.d/credentials.tfrc.json")"
fi
[ -n "${TF_TOKEN_app_terraform_io:-}" ] ||
  fail "No HCP Terraform Cloud auth found. Run 'terraform login' or set TF_TOKEN_app_terraform_io. See docs/hcp/vcs-integration.md."

# Same request pattern as scripts/hcp/bootstrap-workspaces.sh: a real,
# authenticated, read-only lookup of the specific workspace — not just
# token/file presence, which invalid/expired/unrelated credentials pass too.
# The bearer token is passed via a curl config file (-K), not -H directly,
# so it never appears in this process's argv (visible to other users via
# `ps` on a shared machine for the call's duration).
HCP_CURL_CONFIG="$(mktemp)"
trap 'rm -f "${HCP_CURL_CONFIG}"' EXIT
chmod 600 "${HCP_CURL_CONFIG}"
printf 'header = "Authorization: Bearer %s"\n' "${TF_TOKEN_app_terraform_io}" >"${HCP_CURL_CONFIG}"

# set +e/-e around this: a network-level curl failure (DNS, no route, TLS)
# makes the pipeline's exit status (pipefail) non-zero, and a bare failed
# assignment would trip `set -e` before the check below ever runs.
set +e
WORKSPACE_ID="$(
  curl -sS -K "${HCP_CURL_CONFIG}" -H "Content-Type: application/vnd.api+json" \
    "${HCP_API_BASE}/organizations/${HCP_ORG}/workspaces/${HCP_WORKSPACE}" |
    jq -r '.data.id // empty'
)"
set -e
[ -n "${WORKSPACE_ID}" ] ||
  fail "Could not authenticate to HCP org '${HCP_ORG}' workspace '${HCP_WORKSPACE}'. Check that TF_TOKEN_app_terraform_io is valid, unexpired, and scoped to this organization."
echo "OK: authenticated to HCP org '${HCP_ORG}', workspace '${HCP_WORKSPACE}' (id ${WORKSPACE_ID})."

# 2. AWS: confirm the active credentials resolve a caller identity, and
#    surface (never assert against a hardcoded value — no account IDs in
#    git) the account so the operator can eyeball it against the training
#    account. Set TRAINING_EXPECTED_AWS_ACCOUNT_ID to enforce a match.
log "2/5 AWS caller identity"
command -v aws >/dev/null 2>&1 || fail "aws CLI not found. Install the AWS CLI first."
CALLER_IDENTITY="$(aws sts get-caller-identity --output json 2>&1)" ||
  fail "aws sts get-caller-identity failed. Check AWS_PROFILE / AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN (if using temporary credentials) / AWS_REGION for the training account. Output: ${CALLER_IDENTITY}"
CALLER_ACCOUNT="$(printf '%s' "${CALLER_IDENTITY}" | jq -r '.Account')"
echo "OK: AWS credentials resolve to account ${CALLER_ACCOUNT}."
if [ -n "${TRAINING_EXPECTED_AWS_ACCOUNT_ID:-}" ] && [ "${CALLER_ACCOUNT}" != "${TRAINING_EXPECTED_AWS_ACCOUNT_ID}" ]; then
  fail "Active AWS credentials resolve to account ${CALLER_ACCOUNT}, but TRAINING_EXPECTED_AWS_ACCOUNT_ID=${TRAINING_EXPECTED_AWS_ACCOUNT_ID}. Switch AWS_PROFILE or unset TRAINING_EXPECTED_AWS_ACCOUNT_ID to skip this check."
fi

# 3. S3: probe the training bucket's training/ prefix (docs/training/artifact-layout.md).
log "3/5 S3 training bucket probe"
: "${TRAINING_BUCKET_NAME:?TRAINING_BUCKET_NAME is required — set it to the bucket_name from terraform/envs/aws-training (see docs/hcp/provider-variable-map.md). Never hardcode it in a script or commit it.}"
aws s3api list-objects-v2 --bucket "${TRAINING_BUCKET_NAME}" --prefix "training/" --max-items 1 >/dev/null 2>&1 ||
  fail "Could not list s3://${TRAINING_BUCKET_NAME}/training/. Confirm the bucket has been applied (dioscuri-cloud-aws-training workspace) and your IAM identity has s3:ListBucket on it."
echo "OK: s3://${TRAINING_BUCKET_NAME}/training/ is reachable."

# 4. Docker: pull from ECR (with an explicit login first — AWS credentials
#    alone do not authenticate the Docker client) or build training/docker/
#    locally. Fails with a clear, specific blocker if neither is possible —
#    training/docker/ lands with Issue #61 and may not exist yet on a
#    checkout that predates it.
log "4/5 Training image"
command -v docker >/dev/null 2>&1 || fail "docker not found. Install Docker first."
if [ -n "${TRAINING_ECR_REPOSITORY_URL:-}" ]; then
  IMAGE_TAG="${TRAINING_IMAGE_TAG:-latest}"
  REGISTRY_HOST="${TRAINING_ECR_REPOSITORY_URL%%/*}"
  # ECR auth tokens are region-scoped: a login password obtained for the
  # caller's ambient AWS_REGION/profile region fails if the registry itself
  # lives in a different region. The region is always embedded and
  # authoritative in the ECR hostname (<account>.dkr.ecr.<region>.amazonaws.com[.cn]),
  # so parse it from there rather than trusting the caller's default.
  ECR_REGION="$(printf '%s' "${REGISTRY_HOST}" | awk -F. '{print $4}')"
  [ -n "${ECR_REGION}" ] ||
    fail "Could not parse an AWS region from TRAINING_ECR_REPOSITORY_URL (${TRAINING_ECR_REPOSITORY_URL}). Expected an ECR hostname like <account>.dkr.ecr.<region>.amazonaws.com/<repo>."
  ECR_LOGIN_PASSWORD="$(aws ecr get-login-password --region "${ECR_REGION}")" ||
    fail "aws ecr get-login-password --region ${ECR_REGION} failed. Confirm ecr:GetAuthorizationToken on your IAM identity."
  printf '%s' "${ECR_LOGIN_PASSWORD}" | docker login --username AWS --password-stdin "${REGISTRY_HOST}" >/dev/null ||
    fail "docker login to ${REGISTRY_HOST} failed."
  docker pull "${TRAINING_ECR_REPOSITORY_URL}:${IMAGE_TAG}" ||
    fail "docker pull ${TRAINING_ECR_REPOSITORY_URL}:${IMAGE_TAG} failed. Confirm this tag has been pushed."
  echo "OK: pulled ${TRAINING_ECR_REPOSITORY_URL}:${IMAGE_TAG}."
else
  BUILD_CONTEXT="$(cd "$(dirname "$0")/.." && pwd)/training/docker"
  if [ -d "${BUILD_CONTEXT}" ]; then
    docker build -t dioscuri-cloud-training:bootstrap-check "${BUILD_CONTEXT}" ||
      fail "docker build of training/docker failed."
    echo "OK: built dioscuri-cloud-training:bootstrap-check locally."
  else
    fail "training/docker/ not found in this checkout (Issue #61) and TRAINING_ECR_REPOSITORY_URL is unset. Either wait for #61 to land in this branch, or set TRAINING_ECR_REPOSITORY_URL to pull a pre-built image instead."
  fi
fi

# 5. Optional dry-run: GPU node (nvidia-smi via SSM, waited-on and verified —
#    NOT read-only, see header) or SageMaker job describe (read-only).
#    Neither TRAINING_GPU_INSTANCE_ID nor TRAINING_SAGEMAKER_JOB_NAME can
#    exist yet until #53 or #54 provisions one — this step is skip-safe.
log "5/5 Optional dry-run"
if [ -n "${TRAINING_GPU_INSTANCE_ID:-}" ]; then
  SSM_COMMAND_ID="$(
    aws ssm send-command \
      --instance-ids "${TRAINING_GPU_INSTANCE_ID}" \
      --document-name "AWS-RunShellScript" \
      --parameters commands="nvidia-smi" \
      --query "Command.CommandId" --output text 2>&1
  )" ||
    fail "SSM send-command (nvidia-smi dispatch) to ${TRAINING_GPU_INSTANCE_ID} failed: ${SSM_COMMAND_ID}. This requires ssm:SendCommand on the IAM principal running this script (a write permission — this step is not read-only) AND the target instance's own SSM Agent/instance-profile registration (a separate, node-side permission)."

  # The waiter polls ssm:GetCommandInvocation — a separate permission from
  # ssm:SendCommand above. Capture its stderr (and exit status explicitly,
  # since a bare failed assignment would otherwise trip `set -e` before the
  # check below runs) so an AccessDenied here isn't misreported as "the
  # command didn't reach Success".
  set +e
  WAIT_ERROR="$(aws ssm wait command-executed --command-id "${SSM_COMMAND_ID}" --instance-id "${TRAINING_GPU_INSTANCE_ID}" 2>&1 1>/dev/null)"
  WAIT_STATUS=$?
  set -e

  if [ "${WAIT_STATUS}" -eq 0 ]; then
    echo "OK: nvidia-smi via SSM (command ${SSM_COMMAND_ID}) completed successfully on ${TRAINING_GPU_INSTANCE_ID}."
  else
    fail "nvidia-smi via SSM (command ${SSM_COMMAND_ID}) on ${TRAINING_GPU_INSTANCE_ID} did not reach Success: ${WAIT_ERROR}. If this is an AccessDenied on GetCommandInvocation, grant ssm:GetCommandInvocation (separate from ssm:SendCommand) to the calling IAM principal. Otherwise inspect with: aws ssm get-command-invocation --command-id ${SSM_COMMAND_ID} --instance-id ${TRAINING_GPU_INSTANCE_ID}"
  fi
elif [ -n "${TRAINING_SAGEMAKER_JOB_NAME:-}" ]; then
  aws sagemaker describe-training-job --training-job-name "${TRAINING_SAGEMAKER_JOB_NAME}" >/dev/null ||
    fail "aws sagemaker describe-training-job for ${TRAINING_SAGEMAKER_JOB_NAME} failed."
  echo "OK: SageMaker training job ${TRAINING_SAGEMAKER_JOB_NAME} is describable."
else
  echo "SKIPPED: no TRAINING_GPU_INSTANCE_ID or TRAINING_SAGEMAKER_JOB_NAME set — no compute dry-run requested. Expected before #53/#54 provision a node/job."
fi

log "Bootstrap preflight complete"
echo "All required checks passed. See docs/training/bootstrap.md for what each step verified."
