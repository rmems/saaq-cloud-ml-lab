# Bounded GPU training node + IAM instance profile (GitHub #61, consumed by #53).
# instance_count defaults to 0 — the IAM role/profile/security group are $0
# and always created, but no compute is provisioned until a caller opts in.

locals {
  create_key_pair = var.ssh_public_key != null
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-profile"
  role = aws_iam_role.node.name
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "extra" {
  for_each = toset(var.iam_policy_arns)

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_security_group" "node" {
  name        = "${var.name}-sg"
  description = "SSH access for ${var.name}, restricted to operator_cidrs."
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from operator CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.operator_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_key_pair" "node" {
  count = local.create_key_pair ? 1 : 0

  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key
  tags       = var.tags
}

resource "aws_instance" "node" {
  count = var.instance_count

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.node.id]
  iam_instance_profile   = aws_iam_instance_profile.node.name
  key_name               = local.create_key_pair ? aws_key_pair.node[0].key_name : null

  metadata_options {
    http_tokens   = "required" # enforce IMDSv2; IMDSv1 is not permitted
    http_endpoint = "enabled"
  }

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${count.index}"
  })
}
