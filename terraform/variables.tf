variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short project name"
  type        = string
  default     = "nyc-biz-analytics"
}

variable "nyc_business_analytics" {
  description = "Globally unique name for the S3 data lake bucket"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "data_bucket_name" {
  description = "Bucket name"
  type        = string
  default     = "nyc-business-analytics"
}

variable "redshift_admin_username" {
  type    = string
  default = "admin"
}

variable "redshift_base_capacity" {
  type    = number
  default = 8
}

variable "redshift_database_name" {
  type    = string
  default = "nycanalytics"
}

variable "my_ip_cidr" {
  type = string
}

variable "glue_database_name" {
  type    = string
  default = "nyc_raw_data"
}

variable "s3_raw_folder" {
  type    = string
  default = "raw"
}

variable "s3_issued_license_folder_name" {
  type    = string
  default = "issued-licenses"
}

variable "s3_311_folder_name" {
  type    = string
  default = "311-service-request"
}

variable "s3_pluto_folder_name" {
  type    = string
  default = "pluto"
}