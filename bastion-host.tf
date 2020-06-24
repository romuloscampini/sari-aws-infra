variable bh_admin_key_passphrase {
  type        = string
  description = "The passphrase that decrypts the admin user's SSH private key."
}

variable ami_image_id {
  type        = string
  description = "The AMI image to create the Bastion Host instance, backed by the https://github.com/aetion/pkr-bastion-host project."
}

variable "bh_hostnum" {
  type        = number
  description = "The host address offset to be added to the subnet netmask. For a target CIDR block 10.12.41.0, the offset 123 will result in the IP 10.12.41.123."
}

variable "trusted_src_ips" {
  type        = list(string)
  description = "The bastion host will accept SSH connections only from this IP external addresses. "
}

variable bh_admin_username {
  type        = string
  description = "The Bastion Host user with administration rights (sudoer)."
  default     = "admin"
}

variable bh_proxy_username {
  type        = string
  description = "The Bastion Host user whose ~/.ssh/authorized_keys is configured to allow SSH access from end-users. If null or empty, the company's name will be used."
  default     = null
}

resource aws_key_pair bh {
  key_name   = "sari-bh-key"
  public_key = file("admin_id_rsa.pub")
}

resource aws_ssm_parameter bh-pkey {
  name  = "sari.bh_admin_private_key"
  type  = "SecureString"
  value = file("admin_id_rsa")
}

resource aws_ssm_parameter bh-pass {
  name  = "sari.bh_admin_key_passphrase"
  type  = "SecureString"
  value = var.bh_admin_key_passphrase
}

resource aws_security_group bh {
  name        = "SARI Bastion Host SG"
  description = "Allow SSH inbound traffic from VPN Public IPs and CodeBuild SG"
  vpc_id      = data.aws_subnet.public.vpc_id

  ingress {
    description     = "SSH"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.cb.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = formatlist("%s/32", var.trusted_src_ips)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sari-bastion-host"
  }
}

resource aws_instance bh {
  depends_on                  = [aws_key_pair.bh]
  ami                         = var.ami_image_id
  key_name                    = aws_key_pair.bh.key_name
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.bh.id]
  associate_public_ip_address = true
  subnet_id                   = data.aws_subnet.public.id
  private_ip                  = cidrhost(data.aws_subnet.public.cidr_block, var.bh_hostnum)

  tags = merge(local.base_tags, {
    Name = "sari-bastion-host"
  })
}

resource aws_eip bh {
  vpc      = true
  instance = aws_instance.bh.id
}

output bh_instance_id {
  value = aws_instance.bh.id
}

output private_ip {
  value = aws_instance.bh.private_ip
}

output public_ip {
  value = aws_eip.bh.public_ip
}
