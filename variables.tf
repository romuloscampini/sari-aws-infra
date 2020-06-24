variable organization {
  type        = string
  description = "The organization's name."
}

variable environment {
  type        = string
  description = "The name of the environment, e.g., 'dev', 'prod' etc. It's also tha suffix for the SARI configuration project: sari-cfg-ENV."
}

variable aws_region {
  type        = string
  description = "The primary AWS region name."
}

variable kms_decrypt_keys {
  type        = list(string)
  description = "List here all KMS keys required to decrypt the SSM-based RDS passwords."
  default     = []
}

variable sari_version {
  type        = string
  description = "The docker tag for the SARI image."
}

variable gh_user_or_org {
  type        = string
  description = "The GitHub username or organization that owns the SARI configuration project. Defaults to the general organization name."
  default     = null
}

variable gh_token {
  type        = string
  description = "The OAuth token that allows CodeBuild to access the GitHub project's account."
  default     = null
}
