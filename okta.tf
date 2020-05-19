
variable okta_org_name {}

variable okta_api_token {}

variable okta_aws_app_label {}

variable okta_aws_app_iam_user {}

resource aws_ssm_parameter okta {
  name  = "sari.okta_api_token"
  type  = "SecureString"
  value = var.okta_api_token
}

data okta_app_saml aws_app {
  label = var.okta_aws_app_label
}