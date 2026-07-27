variable "aws_profile" {
  type = string
}

variable "primary_region" {
  type    = string
  default = "us-east-1"
}

variable "secondary_region" {
  type    = string
  default = "us-east-2"
}
variable "backup_service_role_name" {
  type    = string
  default = "AWSBackupDefaultServiceRole"
}

variable "account_id" {
  type = string
}

variable "admin_principal_arn" {
  type = string
}

variable "admin_user_name" {
  type = string
}

variable "sso_admin_role_name" {
  type = string
}

variable "warm_key_alias" {
  type = string
}

variable "archive_key_alias" {
  type = string
}

variable "warm_key_description" {
  type = string
}

variable "archive_key_description" {
  type = string
}

variable "warm_vault_name" {
  type = string
}

variable "archive_vault_name" {
  type = string
}
variable "backup_plan_name" {
  type    = string
  default = "BGCC-NS-BackupPlan-EC2-TwoTier-USE1"
}

variable "daily_rule_name" {
  type    = string
  default = "BGCC-NS-Rule-DailyWarm-USE1"
}

variable "monthly_rule_name" {
  type    = string
  default = "BGCC-NS-Rule-Monthly-USE1"
}

variable "daily_assignment_name" {
  type = string
}

variable "monthly_assignment_name" {
  type = string
}

variable "daily_schedule" {
  type    = string
  default = "cron(30 0 ? * * *)"
}

variable "monthly_schedule" {
  type    = string
  default = "cron(0 11 5 * ? *)"
}

variable "timezone" {
  type    = string
  default = "America/New_York"
}

variable "backup_alerts_topic_name" {
  type = string
}

variable "backup_alert_email" {
  type = string
}

variable "backup_job_failure_rule_name" {
  type = string
}

variable "copy_job_failure_rule_name" {
  type = string
}

variable "restore_job_failure_rule_name" {
  type = string
}