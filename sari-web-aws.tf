variable okta_org_name {
  type        = string
  description = "The organization name in the company's Okta account. Defaults to var.organization value."
}

variable okta_api_token {
  type        = string
  description = "The token to access the Okta API."
}

variable idp_name {
  default = "Okta4SARI"
}

resource aws_ssm_parameter okta {
  name  = "sari.okta_api_token"
  type  = "SecureString"
  value = var.okta_api_token
}

data okta_app_saml aws_app {
  label       = "SARI"
  active_only = true
}

data okta_app_metadata_saml aws_app {
  app_id = data.okta_app_saml.aws_app.id
  key_id = data.okta_app_saml.aws_app.key_id
}

resource aws_iam_saml_provider okta {
  name                   = var.idp_name
  saml_metadata_document = data.okta_app_metadata_saml.aws_app.metadata
}

data aws_iam_policy_document sari_assume_role {
  statement {
    sid     = "AssumeRoleWithSAML"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithSAML"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:saml-provider/${aws_iam_saml_provider.okta.name}"]
    }
    condition {
      test     = "StringEquals"
      variable = "SAML:aud"
      values   = ["https://signin.aws.amazon.com/saml"]
    }
  }

  statement {
    sid     = "TagSession"
    effect  = "Allow"
    actions = ["sts:TagSession"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:saml-provider/${aws_iam_saml_provider.okta.name}"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/User"
      values   = ["*"]
    }
  }
}

resource aws_iam_role sari {
  name               = "SARI"
  description        = "Allow access to SARI-enabled databases"
  assume_role_policy = data.aws_iam_policy_document.sari_assume_role.json

  tags = merge(local.base_tags, {
    // SARI-Web requires the 3 tags below:
    "sari:pulumi_backend_url" = "s3://${aws_s3_bucket.backend.bucket}"
    "sari:pulumi_stack_name"  = "sari-${var.environment}"
    "sari:primary_aws_region" = var.aws_region
  })
}

data aws_iam_policy_document sari {
  statement {
    sid       = "ListOwnTags"
    effect    = "Allow"
    actions   = ["iam:ListRoleTags"]
    resources = [aws_iam_role.sari.arn]
  }

  statement {
    sid       = "DescribeDBInstances"
    effect    = "Allow"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadPulumiStack"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.backend.bucket}/*"]
  }
}

resource aws_iam_role_policy sari {
  role   = aws_iam_role.sari.name
  policy = data.aws_iam_policy_document.sari.json
}
