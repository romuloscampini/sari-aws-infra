provider aws {
  version = "2.67"
  region  = var.aws_region
}

provider okta {
  version   = "3.3.0"
  org_name  = var.okta_org_name
  api_token = var.okta_api_token
}

provider random {
  version = "2.2.1"
}
