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
      values   = [data.aws_subnet.private.arn]
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
    resources = formatlist("arn:aws:ssm:%s:${local.account_id}:parameter/*", var.aws_regions)
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
    sid    = "SARIManagedResources"
    effect = "Allow"
    actions = [
      "events:*",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "glue:CreateConnection",
      "glue:DeleteConnection",
      "glue:GetConnection",
      "glue:UpdateConnection",
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
    resources = formatlist("arn:aws:ssm:%s:${local.account_id}:parameter/*", var.aws_regions)
  }

  statement {
    sid    = "SARIEncryptGluePasswords"
    effect = "Allow"
    actions = [
      "kms:Encrypt"
    ]
    resources = [aws_kms_key.glue_passwords.arn]
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
  name   = "SARI CodeBuild"
  vpc_id = data.aws_subnet.private.vpc_id

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
  name          = "run-sari"
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
    location            = "https://github.com/${coalesce(var.gh_user_or_org, var.organization)}/sari-cfg-${var.environment}.git"
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
    BH_ADMIN_USERNAME: "${var.bh_admin_username}"
    BH_HOSTNAME: "${aws_instance.bh.private_ip}"
    BH_PROXY_USERNAME: "${coalesce(var.bh_proxy_username, var.organization)}"
    OKTA_AWS_APP_IAM_IDP: "${var.okta_aws_app_iam_idp}"
    OKTA_AWS_APP_ID: "${data.okta_app_saml.aws_app.id}"
    OKTA_ORG_NAME: "${coalesce(var.okta_org_name, var.organization)}"
    PULUMI_BACKEND_URL: "s3://${aws_s3_bucket.backend.bucket}"
    PULUMI_SKIP_UPDATE_CHECK: "true"
    PULUMI_STACK_NAME: "sari-${var.environment}"
    SARI_IAM_TRIGGER_ROLE_NAME: "${aws_iam_role.build_start.name}"

  parameter-store:
    BH_ADMIN_KEY_PASSPHRASE: "sari.bh_admin_key_passphrase"
    BH_ADMIN_PRIVATE_KEY: "sari.bh_admin_private_key"
    OKTA_API_TOKEN: "sari.okta_api_token"
    PULUMI_CONFIG_PASSPHRASE: "sari.pulumi_config_passphrase"

phases:
  build:
    commands:
      - cd $HOME
      - export SARI_CONFIG=$CODEBUILD_SRC_DIR
      - export CI=$CODEBUILD_CI
      - pulumi version
      - pulumi --non-interactive login --cloud-url $PULUMI_BACKEND_URL
      - pulumi --non-interactive stack select $PULUMI_STACK_NAME --create
      - eval $(./run-proxy.sh)
      - pulumi --logtostderr -v=2 --non-interactive up --yes --skip-preview
EOT
  }

  source_version = "master"

  vpc_config {
    vpc_id = data.aws_subnet.private.vpc_id

    subnets = [
      data.aws_subnet.private.id
    ]

    security_group_ids = [
      aws_security_group.cb.id
    ]
  }

  tags = merge(local.base_tags, {
    Name = "run-sari"
  })
}

// GitHub Integration

resource aws_codebuild_source_credential gh {
  count       = var.gh_token != null ? 1 : 0
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.gh_token
}

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

// CloudWatch StartBuild

data aws_iam_policy_document assume_build_start {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource aws_iam_role build_start {
  name               = "SARITriggerRun"
  path               = "/service-role/"
  assume_role_policy = data.aws_iam_policy_document.assume_build_start.json
}

data aws_iam_policy_document build_start {
  statement {
    sid       = "1"
    effect    = "Allow"
    actions   = ["codebuild:StartBuild"]
    resources = [aws_codebuild_project.this.arn]
  }
}

resource aws_iam_role_policy build_start {
  role = aws_iam_role.build_start.name

  policy = data.aws_iam_policy_document.build_start.json
}
