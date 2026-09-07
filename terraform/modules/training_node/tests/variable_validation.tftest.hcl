# Tests for the validation blocks in variables.tf: instance_count (whole
# number, 0-2) and operator_cidrs (same intentional-fail-on-default pattern
# as terraform/envs/oracle-dev/tests/operator_cidrs_validation.tftest.hcl).
#
# Run with: terraform -chdir=terraform/modules/training_node test
#           (requires Terraform >= 1.7 for mock_provider support)

mock_provider "aws" {}

# aws_iam_policy_document is a logical data source (computes `json` purely
# from its own config, no API call) but mock_provider intercepts ALL data
# reads for the provider, so its computed `json` comes back unusable unless
# overridden here.
override_data {
  target = data.aws_iam_policy_document.assume_role
  values = {
    json = "{}"
  }
}

# ── Shared baseline variables (all required inputs, valid values) ─────────────

variables {
  ami_id         = "ami-0123456789abcdef0"
  subnet_id      = "subnet-0123456789abcdef0"
  vpc_id         = "vpc-0123456789abcdef0"
  operator_cidrs = ["203.0.113.0/24"]
}

# ─────────────────────────────────────────────────────────────────────────────
# instance_count — valid inputs must NOT raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "valid_instance_count_zero_passes" {
  command = plan

  variables {
    instance_count = 0
  }
}

run "valid_instance_count_two_passes" {
  command = plan

  variables {
    instance_count = 2
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# instance_count — invalid inputs MUST raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "rejects_negative_instance_count" {
  command = plan

  variables {
    instance_count = -1
  }

  expect_failures = [var.instance_count]
}

run "rejects_instance_count_above_bound" {
  command = plan

  variables {
    instance_count = 3
  }

  expect_failures = [var.instance_count]
}

run "rejects_fractional_instance_count" {
  # This is the exact regression CodeAnt flagged: a fractional value inside
  # the numeric range previously passed this validation and only failed
  # later, at the point Terraform requires an integer for `count`.
  command = plan

  variables {
    instance_count = 1.5
  }

  expect_failures = [var.instance_count]
}

# ─────────────────────────────────────────────────────────────────────────────
# operator_cidrs — valid inputs must NOT raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "valid_operator_cidrs_pass" {
  command = plan

  variables {
    operator_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# operator_cidrs — invalid inputs MUST raise an error
# ─────────────────────────────────────────────────────────────────────────────

run "rejects_default_placeholder_cidr" {
  # Intentional guardrail (matches oracle-dev precedent): the placeholder
  # default must fail so a caller can't silently use it.
  command = plan

  variables {
    operator_cidrs = ["10.0.0.0/8"]
  }

  expect_failures = [var.operator_cidrs]
}

run "rejects_empty_operator_cidrs" {
  command = plan

  variables {
    operator_cidrs = []
  }

  expect_failures = [var.operator_cidrs]
}
