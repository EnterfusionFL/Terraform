#### backup Role #####
data "aws_iam_policy_document" "aws_backup_assume_role" {
  statement {
    sid    = "AllowAWSBackupToAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "aws_backup_default_service_role" {
  name               = var.backup_service_role_name
  assume_role_policy = data.aws_iam_policy_document.aws_backup_assume_role.json

}

resource "aws_iam_role_policy_attachment" "backup_full_access" {
  role       = aws_iam_role.aws_backup_default_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupFullAccess"
}

resource "aws_iam_role_policy_attachment" "backup_service_role_backup" {
  role       = aws_iam_role.aws_backup_default_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_service_role_restores" {
  role       = aws_iam_role.aws_backup_default_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

#####KMS###########

locals {
  backup_service_role_arn = aws_iam_role.aws_backup_default_service_role.arn

  sso_admin_role_arn = "arn:aws:iam::${var.account_id}:role/aws-reserved/sso.amazonaws.com/${var.sso_admin_role_name}"

  key_admins = compact([
    var.admin_principal_arn
  ])

  key_users = compact([
    var.admin_principal_arn,
    local.backup_service_role_arn,
    local.sso_admin_role_arn
  ])
}

module "backup_kms" {
  source = "../../modules/backup"

  providers = {
    aws      = aws
    aws.use2 = aws.use2
  }

  warm_key_alias          = "PCCC-NS-KMS-WarmVault-USE1"
  archive_key_alias       = "PCCC-NS-KMS-ArchiveVault-USE2"
  warm_key_description    = "KMS key for warm vault in us-east-1"
  archive_key_description = "KMS key for archive vault in us-east-2"

  key_administrator_arns = local.key_admins
  key_user_arns          = local.key_users

}

#####Vault#####

resource "aws_backup_vault" "warm_use1" {
  name        = var.warm_vault_name
  kms_key_arn = module.backup_kms.warm_key_arn
}

resource "aws_backup_vault" "archive_use2" {
  provider    = aws.use2
  name        = var.archive_vault_name
  kms_key_arn = module.backup_kms.archive_key_arn
}

resource "aws_backup_vault_lock_configuration" "warm_use1" {
  backup_vault_name  = aws_backup_vault.warm_use1.name
  min_retention_days = 8
  max_retention_days = 35
}

resource "aws_backup_vault_lock_configuration" "archive_use2" {
  provider           = aws.use2
  backup_vault_name  = aws_backup_vault.archive_use2.name
  min_retention_days = 365
  max_retention_days = 370
}

####Backup Plan####
resource "aws_backup_plan" "ec2_two_tier_use1" {
  name = var.backup_plan_name

  rule {
    rule_name         = var.daily_rule_name
    target_vault_name = aws_backup_vault.warm_use1.name
    schedule          = var.daily_schedule

    start_window      = 60
    completion_window = 480

    lifecycle {
      delete_after = 35
    }

    enable_continuous_backup     = false
    schedule_expression_timezone = var.timezone
  }

  rule {
    rule_name         = var.monthly_rule_name
    target_vault_name = aws_backup_vault.warm_use1.name
    schedule          = var.monthly_schedule

    start_window      = 480
    completion_window = 1440

    lifecycle {
      delete_after = 8
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.archive_use2.arn

      lifecycle {
        delete_after = 365
      }
    }

    enable_continuous_backup     = false
    schedule_expression_timezone = var.timezone
  }

  advanced_backup_setting {
    resource_type = "EC2"

    backup_options = {
      WindowsVSS = "disabled"
    }
  }
}

### Backup Assignment#############

resource "aws_backup_selection" "daily_ec2_instances" {
  iam_role_arn = aws_iam_role.aws_backup_default_service_role.arn
  name         = var.daily_assignment_name
  plan_id      = aws_backup_plan.ec2_two_tier_use1.id

  resources = [
    "arn:aws:ec2:*:*:instance/*"
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/BackupDaily"
      value = "True"
    }
  }
}

resource "aws_backup_selection" "monthly_ec2_instances" {
  iam_role_arn = aws_iam_role.aws_backup_default_service_role.arn
  name         = var.monthly_assignment_name
  plan_id      = aws_backup_plan.ec2_two_tier_use1.id

  resources = [
    "arn:aws:ec2:*:*:instance/*"
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/BackupMonthly"
      value = "True"
    }
  }
}