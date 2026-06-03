output "warm_key_arn" {
  value = module.backup_kms.warm_key_arn
}

output "archive_key_arn" {
  value = module.backup_kms.archive_key_arn
}

output "warm_key_alias" {
  value = module.backup_kms.warm_key_alias
}

output "archive_key_alias" {
  value = module.backup_kms.archive_key_alias
}

output "warm_vault_name" {
  value = aws_backup_vault.warm_use1.name
}

output "warm_vault_arn" {
  value = aws_backup_vault.warm_use1.arn
}

output "archive_vault_name" {
  value = aws_backup_vault.archive_use2.name
}

output "archive_vault_arn" {
  value = aws_backup_vault.archive_use2.arn
}

output "backup_plan_id" {
  value = aws_backup_plan.ec2_two_tier_use1.id
}

output "daily_rule_name" {
  value = var.daily_rule_name
}

output "monthly_rule_name" {
  value = var.monthly_rule_name
}

output "daily_assignment_name" {
  value = aws_backup_selection.daily_ec2_instances.name
}

output "monthly_assignment_name" {
  value = aws_backup_selection.monthly_ec2_instances.name
}