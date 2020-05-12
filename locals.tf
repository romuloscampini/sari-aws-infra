data aws_caller_identity current {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  base_tags = {
    Client       = var.company
    Environment  = var.environment
    Region       = var.aws_region
    Account      = local.account_id
    Provisioning = "terraform"
  }
}
