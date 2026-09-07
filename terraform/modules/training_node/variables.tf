variable "name" {
  description = "Base name for resources created by this module (IAM role, instance profile, security group, instances)."
  type        = string
  default     = "dioscuri-cloud-training-node"
}

variable "instance_count" {
  description = "Number of GPU training instances to launch. Defaults to 0 so instantiating this module creates no billable compute — the caller must explicitly opt in per docs/runbooks/gpu-smoke-test-readiness.md."
  type        = number
  default     = 0

  validation {
    condition     = var.instance_count >= 0 && var.instance_count <= 2 && var.instance_count == floor(var.instance_count)
    error_message = "instance_count must be a whole number between 0 and 2 (0 disables the node entirely; safety bound for GPU instances — see docs/runbooks/gpu-smoke-test-readiness.md)."
  }
}

variable "instance_type" {
  description = "EC2 instance type. Default is the smallest common single-GPU type; document the reason for any change per docs/runbooks/gpu-smoke-test-readiness.md item 4."
  type        = string
  default     = "g4dn.xlarge"
}

variable "ami_id" {
  description = "AMI ID for the GPU node (e.g. an AWS Deep Learning AMI with CUDA drivers). Region- and version-specific — no safe default. See providers/aws/training-image-runbook.md for how to find the current AMI ID."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance(s) into."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID that owns var.subnet_id, used to scope the security group."
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key content for operator access. If null, no key pair is created and no SSH access is configured."
  type        = string
  sensitive   = true
  default     = null
}

variable "operator_cidrs" {
  description = "List of operator source CIDRs allowed to reach SSH. REQUIRED: set to the operator's actual VPN/office CIDRs; the default is a non-routable example and will not match real operator IPs."
  type        = list(string)
  default     = ["10.0.0.0/8"]

  validation {
    condition     = length(var.operator_cidrs) > 0 && !contains(var.operator_cidrs, "10.0.0.0/8")
    error_message = "operator_cidrs must be set to real operator VPN/office CIDRs; the default 10.0.0.0/8 is a non-routable example and will lock out all access."
  }
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 100
}

variable "iam_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the instance role (e.g. the training_bucket_rw policy ARN output by terraform/envs/aws-training)."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources. Callers should include owner, github, pr, and teardown_by per docs/credits/usage-policy.md — this module does not enforce specific keys, only applies whatever is passed."
  type        = map(string)
  default     = {}
}
