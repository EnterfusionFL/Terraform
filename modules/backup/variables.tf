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

variable "key_administrator_arns" {
  type = list(string)
}

variable "key_user_arns" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}