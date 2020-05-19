variable company {
  default = "acme"
}

variable environment {
}

variable aws_region {
}

variable kms_decrypt_keys {
  type    = list(string)
  default = []
}

variable sari_version {}

variable gh_token {}
