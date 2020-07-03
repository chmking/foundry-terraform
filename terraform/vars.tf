variable "key_name" {
  type = string
  description = "The key pair name to be assigned to the server"
}

variable "bucket_name" {
  type = string
  description = "The storage bucket name (avoid using .'s)"
}

variable "vpc" {
  type = string
  description = "The VPC ID for the server"
}

variable "record_name" {
  type = string
  description = "The Route53 record name"
}

variable "zone_id" {
  type = string
  description = "The Route53 zone ID"
}

