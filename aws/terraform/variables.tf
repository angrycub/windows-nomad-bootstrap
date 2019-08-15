variable "region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS Profile for Keys"
  default = "default"
}

variable "name" {
  description = "Used to name various infrastructure components"
  default     = "hashistack"
}

variable "key_name" {}

variable "server_count" {
  default = "1"
}

variable "client_count" {
  default = "1"
}

variable "ami" {}

variable "ssh_key" {}

