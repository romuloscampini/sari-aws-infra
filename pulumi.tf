resource aws_s3_bucket backend {
  bucket = "backend.sari.${var.environment}.${var.company}.com"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = merge(local.base_tags, {
    Name = "SARI Backend"
  })
}

resource aws_ssm_parameter pulumi {
  name  = "sari.pulumi_config_passphrase"
  type  = "SecureString"
  value = "6K9xHiV7DrUhsDN9G5Bn66PBkVxj4byt"
}
