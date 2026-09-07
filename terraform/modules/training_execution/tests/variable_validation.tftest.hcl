# Tests for the ecr_untagged_image_expiry_days validation block in
# variables.tf (must be a positive whole number, same class of bug fixed
# for the lifecycle-duration variables in terraform/envs/aws-training).
#
# Run with: terraform -chdir=terraform/modules/training_execution test
#           (requires Terraform >= 1.7 for mock_provider support)

mock_provider "aws" {}

# Both aws_iam_policy_document data sources here are logical (compute `json`
# purely from config, no API call), but mock_provider intercepts all data
# reads for the provider — override so their `json` output is usable.
override_data {
  target = data.aws_iam_policy_document.assume_role
  values = {
    json = "{}"
  }
}

override_data {
  target = data.aws_iam_policy_document.execution
  values = {
    json = "{}"
  }
}

variables {
  bucket_arn = "arn:aws:s3:::dioscuri-cloud-training-test"
}

# ─────────────────────────────────────────────────────────────────────────────
# Valid inputs — validation must NOT raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "valid_default_expiry_passes" {
  command = plan
}

run "valid_minimum_expiry_passes" {
  command = plan

  variables {
    ecr_untagged_image_expiry_days = 1
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Invalid inputs — validation MUST raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "rejects_zero_expiry" {
  command = plan

  variables {
    ecr_untagged_image_expiry_days = 0
  }

  expect_failures = [var.ecr_untagged_image_expiry_days]
}

run "rejects_negative_expiry" {
  command = plan

  variables {
    ecr_untagged_image_expiry_days = -3
  }

  expect_failures = [var.ecr_untagged_image_expiry_days]
}

run "rejects_fractional_expiry" {
  command = plan

  variables {
    ecr_untagged_image_expiry_days = 2.5
  }

  expect_failures = [var.ecr_untagged_image_expiry_days]
}
