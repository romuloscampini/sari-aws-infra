variable bh_admin_key_passphrase {}

variable ami_image_id {}

variable "hostnum" {
  description = "The host address offset to be added to the subnet netmask."
  type        = number
}

variable "trusted_src_ip" {
  type = string
}

resource aws_key_pair bh {
  key_name   = "bh-key"
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
  name = "SARI Bastion Host SG"
  // FIXME: fix the description later since its modification implies recreating the SG
  description = "Allow SSH inbound traffic from trusted IPs"
  vpc_id      = aws_vpc.sari.id

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

    cidr_blocks = ["${var.trusted_src_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sari-sg"
  }
}

resource aws_instance bh {
  depends_on                  = [aws_key_pair.bh]
  ami                         = var.ami_image_id
  key_name                    = aws_key_pair.bh.key_name
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.bh.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.public.id
  private_ip                  = cidrhost(aws_subnet.public.cidr_block, var.hostnum)

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
