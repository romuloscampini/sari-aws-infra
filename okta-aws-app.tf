variable okta_aws_app_label {
  type        = string
  description = "The full name of the Okta AWS Application."
}

data okta_app_saml aws_app {
  label = var.okta_aws_app_label
}
