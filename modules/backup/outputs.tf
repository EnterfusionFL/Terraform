output "warm_key_arn" {
  value = aws_kms_key.warm_use1.arn
}

output "warm_key_alias" {
  value = aws_kms_alias.warm_use1.name
}

output "archive_key_arn" {
  value = aws_kms_key.archive_use2.arn
}

output "archive_key_alias" {
  value = aws_kms_alias.archive_use2.name
}