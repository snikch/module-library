variable "bucket_names" {
  type = list(string)
}

variable "acl" {
  type = string
  default = "private"
}

variable "policy_prefix" {
  type = string
}