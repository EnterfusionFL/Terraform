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
  source = "../../../modules/backup"

  providers = {
    aws      = aws
    aws.use2 = aws.use2
  }

  warm_key_alias          = var.warm_key_alias
  archive_key_alias       = var.archive_key_alias
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

###### SNS ######

resource "aws_sns_topic" "backup_failure_alerts" {
  name         = var.backup_alerts_topic_name
  display_name = var.backup_alerts_topic_name
}

resource "aws_sns_topic_subscription" "backup_failure_email" {
  topic_arn = aws_sns_topic.backup_failure_alerts.arn
  protocol  = "email"
  endpoint  = var.backup_alert_email
}

###### EventBridge ######

resource "aws_cloudwatch_event_rule" "backup_job_failure" {
  name        = var.backup_job_failure_rule_name
  description = "Capture failed, aborted, or expired AWS Backup backup jobs"

  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = ["Backup Job State Change"]
    detail = {
      state = ["FAILED", "ABORTED", "EXPIRED"]
    }
  })


}

resource "aws_cloudwatch_event_target" "backup_job_failure_to_sns" {
  rule      = aws_cloudwatch_event_rule.backup_job_failure.name
  target_id = "BackupFailureAlerts"
  arn       = aws_sns_topic.backup_failure_alerts.arn
}

resource "aws_cloudwatch_event_rule" "copy_job_failure" {
  name        = var.copy_job_failure_rule_name
  description = "Capture failed, aborted, or expired AWS Backup copy jobs"

  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = ["Copy Job State Change"]
    detail = {
      state = ["FAILED", "ABORTED", "EXPIRED"]
    }
  })


}

resource "aws_cloudwatch_event_target" "copy_job_failure_to_sns" {
  rule      = aws_cloudwatch_event_rule.copy_job_failure.name
  target_id = "CopyFailureAlerts"
  arn       = aws_sns_topic.backup_failure_alerts.arn
}

resource "aws_cloudwatch_event_rule" "restore_job_failure" {
  name        = var.restore_job_failure_rule_name
  description = "Capture failed, aborted, or expired AWS Backup restore jobs"

  event_pattern = jsonencode({
    source      = ["aws.backup"]
    detail-type = ["Restore Job State Change"]
    detail = {
      status = ["FAILED", "ABORTED", "EXPIRED"]
    }
  })


}

resource "aws_cloudwatch_event_target" "restore_job_failure_to_sns" {
  rule      = aws_cloudwatch_event_rule.restore_job_failure.name
  target_id = "RestoreFailureAlerts"
  arn       = aws_sns_topic.backup_failure_alerts.arn
}

resource "aws_sns_topic_policy" "allow_eventbridge_publish" {
  arn = aws_sns_topic.backup_failure_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.backup_failure_alerts.arn
      }
    ]
  })
}