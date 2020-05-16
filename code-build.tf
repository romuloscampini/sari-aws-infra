resource aws_codebuild_source_credential gh {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.gh_token
}

data aws_iam_policy_document service_role {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource aws_iam_role service_role {
  name = "codebuild-build-sari-service-role"

  assume_role_policy = data.aws_iam_policy_document.service_role.json
}

data aws_iam_policy_document service_role_policy {
  statement {
    sid    = "CloudWatchLogsPolicy"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:CreatePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicies",
      "iam:ListRoles",
      "iam:PassRole",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterfacePermission"
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:network-interface/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "ec2:Subnet"
      values   = [aws_subnet.private1.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameters", // Access PARAMETER_STORE-based variables
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/*"]
  }

  statement {
    sid    = "BackendBucket"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.backend.arn,
      "${aws_s3_bucket.backend.arn}/*"
    ]
  }

  statement {
    sid    = "SARIManageResources"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UpdateAssumeRolePolicy",
      "rds:DescribeDBInstances",
      "rds:ListTagsForResource",
      "s3:GetObject",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SARIRetrieveMasterPasswords"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = ["arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/*"]
  }

  dynamic "statement" {
    for_each = var.kms_decrypt_keys
    content {
      sid    = "SARIDecryptMasterPasswords${statement.key}"
      effect = "Allow"
      actions = [
        "kms:Decrypt"
      ]
      resources = [
        "arn:aws:kms:${var.aws_region}:${local.account_id}:key/${statement.value}"
      ]
    }
  }
}

resource aws_iam_role_policy service_role_policy {
  role = aws_iam_role.service_role.name

  policy = data.aws_iam_policy_document.service_role_policy.json
}

resource aws_security_group cb {
  name        = "SARI CodeBuild"
  description = "Allow SSH & DB inbound traffic"
  vpc_id      = aws_vpc.sari.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sari-code-build-sg"
  }
}

resource aws_codebuild_project this {
  name          = "build-sari"
  description   = "Secure Access to RDS Instances - ${upper(var.environment)} Build"
  build_timeout = "15"
  service_role  = aws_iam_role.service_role.arn
  badge_enabled = true

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "quay.io/eliezio/sari:${var.sari_version}"
    type         = "LINUX_CONTAINER"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/sari"
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/eliezio/sari-${var.environment}.git"
    report_build_status = true
    git_clone_depth     = 1

    git_submodules_config {
      fetch_submodules = true
    }

    buildspec = <<-EOT
version: 0.2

run-as: pulumi

env:
  variables:
    PULUMI_BACKEND_URL: "s3://${aws_s3_bucket.backend.bucket}"
  parameter-store:
    PULUMI_CONFIG_PASSPHRASE: "sari.pulumi_config_passphrase"
    OKTA_API_TOKEN: "sari.okta_api_token"
    BH_ADMIN_PRIVATE_KEY: "sari.bh_admin_private_key"
    BH_ADMIN_KEY_PASSPHRASE: "sari.bh_admin_key_passphrase"

phases:
  build:
    commands:
      - cd $HOME
      - export CONFIG=$CODEBUILD_SRC_DIR
      - export CI=$CODEBUILD_CI
      - pulumi version
      - pulumi --non-interactive login --cloud-url $PULUMI_BACKEND_URL
      - pulumi --non-interactive stack select this --create
      - pulumi --logtostderr -v=2 --non-interactive up --yes --skip-preview
EOT
  }

  source_version = "master"

  vpc_config {
    vpc_id = aws_vpc.sari.id

    subnets = [
      aws_subnet.private1.id
    ]

    security_group_ids = [
      aws_security_group.cb.id
    ]
  }

  tags = merge(local.base_tags, {
    Name = "sari-code-build"
  })
}

// GitHub

resource aws_codebuild_webhook this {
  project_name = aws_codebuild_project.this.name

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "master"
    }
  }
}
