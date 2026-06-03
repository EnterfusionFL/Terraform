data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowKeyAdministrators"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.key_administrator_arns
    }

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowKeyUsers"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.key_user_arns
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }
}

resource "aws_kms_key" "warm_use1" {
  description              = var.warm_key_description
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = false
  deletion_window_in_days  = 30
  is_enabled               = true
  policy                   = data.aws_iam_policy_document.kms_policy.json
  tags = merge(var.tags, {
    Name   = var.warm_key_alias
  })
}

resource "aws_kms_alias" "warm_use1" {
  name          = "alias/${var.warm_key_alias}"
  target_key_id = aws_kms_key.warm_use1.key_id
}

resource "aws_kms_key" "archive_use2" {
  provider                 = aws.use2
  description              = var.archive_key_description
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = false
  deletion_window_in_days  = 30
  is_enabled               = true
  policy                   = data.aws_iam_policy_document.kms_policy.json
  tags = merge(var.tags, {
    Name   = var.archive_key_alias
    
  })
}

resource "aws_kms_alias" "archive_use2" {
  provider      = aws.use2
  name          = "alias/${var.archive_key_alias}"
  target_key_id = aws_kms_key.archive_use2.key_id
}