provider aws {
  version = "2.62"
  region  = var.aws_region
}

provider random {
  version = "2.2.1"
}