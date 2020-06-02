
variable okta_org_name {
  type        = string
  description = "The organization name in the company's Okta account. Defaults to var.organization value."
}

variable okta_api_token {
  type        = string
  description = "The token to access the Okta API."
}

variable okta_aws_app_label {
  type        = string
  description = "The full name of the Okta AWS Application."
}

variable okta_aws_app_iam_idp {
  type        = string
  description = "The IAM IdP name that references Okta as a SAML 2.0 Identity Provider."
}

resource aws_ssm_parameter okta {
  name  = "sari.okta_api_token"
  type  = "SecureString"
  value = var.okta_api_token
}

data okta_app_saml aws_app {
  label = var.okta_aws_app_label
}