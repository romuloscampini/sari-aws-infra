
variable okta_api_token {}

resource aws_ssm_parameter okta {
  name  = "sari.okta_api_token"
  type  = "SecureString"
  value = var.okta_api_token
}
