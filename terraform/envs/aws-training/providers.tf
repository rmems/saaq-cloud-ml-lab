# AWS credentials and region come from HCP Terraform workspace ENVIRONMENT
# variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION), read
# natively by the AWS provider's SDK credential chain. Do not add sensitive
# `variable` blocks for these, and do not pass explicit
# access_key/secret_key/region arguments here.
#
# See docs/hcp/provider-variable-map.md (AWS section) and
# docs/hcp/workspaces.md (Workspace Variables).
provider "aws" {}
