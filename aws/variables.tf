variable "region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "name" {
  description = "Used to name various infrastructure components"
  default     = "hashistack"
}

variable "key_name" {}

variable "server_count" {
  default     = "1"
}
