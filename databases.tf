variable mysql_major_version {
  default = "5.7"
}

variable mysql_patch_version {
  default = "28"
}

variable db_names {
  type = list(string)
  default = [
    "blackwells",
    "whsmith"
  ]
}

locals {
  major_version_id = replace(var.mysql_major_version, ".", "-")
}

resource random_password password {
  for_each = toset(var.db_names)

  length  = 32
  special = false
}

resource aws_ssm_parameter pwd {
  for_each = toset(var.db_names)

  name  = "${each.value}.master_password"
  type  = "SecureString"
  value = random_password.password[each.value].result
}

resource aws_db_option_group mysql-audit {
  name                     = "mysql${local.major_version_id}-audit"
  option_group_description = "MySQL Option Group for Audited Access"
  engine_name              = "mysql"
  major_engine_version     = var.mysql_major_version
  option {
    option_name = "MARIADB_AUDIT_PLUGIN"
    option_settings {
      name  = "SERVER_AUDIT_EXCL_USERS"
      value = "rdsadmin"
    }
  }
}

resource aws_db_subnet_group default {
  name       = "sari"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource aws_security_group rds {
  name        = "SARI RDS"
  description = "Allow DB inbound traffic"
  vpc_id      = aws_vpc.sari.id

  ingress {
    description     = "MySQL/MariaDB"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bh.id]
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

resource aws_db_instance instance {
  for_each = toset(var.db_names)

  identifier                          = each.value
  skip_final_snapshot                 = true
  instance_class                      = "db.t2.micro"
  engine                              = "mysql"
  engine_version                      = "${var.mysql_major_version}.${var.mysql_patch_version}"
  name                                = "db_${each.value}"
  username                            = var.company
  password                            = aws_ssm_parameter.pwd[each.value].value
  option_group_name                   = aws_db_option_group.mysql-audit.name
  allocated_storage                   = 20
  max_allocated_storage               = 0
  db_subnet_group_name                = aws_db_subnet_group.default.name
  vpc_security_group_ids              = [aws_security_group.rds.id]
  iam_database_authentication_enabled = true
  backup_retention_period             = 0
  enabled_cloudwatch_logs_exports     = ["audit", "error", "general"]
  allow_major_version_upgrade         = false
  auto_minor_version_upgrade          = false

  apply_immediately = true
}
