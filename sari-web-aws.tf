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
}

resource aws_iam_role sari {
  name               = "SARI"
  description        = "Allow access to SARI-enabled databases"
  assume_role_policy = data.aws_iam_policy_document.sari_assume_role.json

  tags = merge(local.base_tags, {
  })
}

data aws_iam_policy_document sari {
  statement {
    sid       = "DescribeDBInstances"
    effect    = "Allow"
    actions   = ["rds:DescribeDBInstances"]
    resources = ["*"]
  }
}

resource aws_iam_role_policy sari {
  role   = aws_iam_role.sari.name
  policy = data.aws_iam_policy_document.sari.json
}
