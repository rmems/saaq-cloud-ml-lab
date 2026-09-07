# Tests for the validation blocks in variables.tf: bucket_name (S3 naming
# rules) and the two lifecycle-duration variables (must be positive whole
# numbers — see the review findings fixed for GitHub #47).
#
# Run with: terraform -chdir=terraform/envs/aws-training test
#           (requires Terraform >= 1.7 for mock_provider support)

mock_provider "aws" {}

# ── Shared baseline variables (all required inputs, valid values) ─────────────

variables {
  bucket_name = "dioscuri-cloud-training-test"
}

# ─────────────────────────────────────────────────────────────────────────────
# bucket_name — valid inputs must NOT raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "valid_bucket_name_passes" {
  command = plan

  variables {
    bucket_name = "dioscuri-cloud-training-test"
  }
}

run "valid_bucket_name_with_periods_and_hyphens_passes" {
  command = plan

  variables {
    bucket_name = "dioscuri-cloud.training-test-2"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# bucket_name — invalid inputs MUST raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "rejects_uppercase_bucket_name" {
  command = plan

  variables {
    bucket_name = "Dioscuri-Cloud-Training"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_bucket_name_too_short" {
  command = plan

  variables {
    bucket_name = "ab"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_bucket_name_with_underscore" {
  command = plan

  variables {
    bucket_name = "dioscuri_cloud_training"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_bucket_name_with_consecutive_periods" {
  command = plan

  variables {
    bucket_name = "dioscuri..cloud"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_ip_address_like_bucket_name" {
  command = plan

  variables {
    bucket_name = "192.168.1.1"
  }

  expect_failures = [var.bucket_name]
}

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle-duration variables — valid inputs must NOT raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "valid_lifecycle_days_pass" {
  command = plan

  variables {
    noncurrent_version_expiration_days     = 90
    abort_incomplete_multipart_upload_days = 7
  }
}

run "valid_minimum_lifecycle_days_pass" {
  command = plan

  variables {
    noncurrent_version_expiration_days     = 1
    abort_incomplete_multipart_upload_days = 1
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Lifecycle-duration variables — invalid inputs MUST raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "rejects_zero_noncurrent_version_expiration_days" {
  command = plan

  variables {
    noncurrent_version_expiration_days = 0
  }

  expect_failures = [var.noncurrent_version_expiration_days]
}

run "rejects_negative_noncurrent_version_expiration_days" {
  command = plan

  variables {
    noncurrent_version_expiration_days = -5
  }

  expect_failures = [var.noncurrent_version_expiration_days]
}

run "rejects_fractional_noncurrent_version_expiration_days" {
  command = plan

  variables {
    noncurrent_version_expiration_days = 1.5
  }

  expect_failures = [var.noncurrent_version_expiration_days]
}

run "rejects_zero_abort_incomplete_multipart_upload_days" {
  command = plan

  variables {
    abort_incomplete_multipart_upload_days = 0
  }

  expect_failures = [var.abort_incomplete_multipart_upload_days]
}

run "rejects_fractional_abort_incomplete_multipart_upload_days" {
  command = plan

  variables {
    abort_incomplete_multipart_upload_days = 2.5
  }

  expect_failures = [var.abort_incomplete_multipart_upload_days]
}
