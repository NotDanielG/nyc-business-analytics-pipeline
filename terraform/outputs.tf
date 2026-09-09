output "data_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.data_lake.id
}

output "data_bucket_arn" {
  value = aws_s3_bucket.data_lake.arn
}

output "pipeline_execution_role_arn" {
  description = "Role ARN for Lambda/Glue"
  value       = aws_iam_role.pipeline_execution.arn
}

output "dev_access_key_id" {
  description = "Access key ID for local development"
  value       = aws_iam_access_key.local_dev.id
  sensitive   = true
}

output "dev_secret_access_key" {
  description = "Secret access key"
  value       = aws_iam_access_key.local_dev.secret
  sensitive   = true
}

output "redshift_workgroup_endpoint" {
  value = aws_redshiftserverless_workgroup.main.endpoint[0].address
}

output "redshift_port" {
  value = aws_redshiftserverless_workgroup.main.endpoint[0].port
}

output "redshift_database_name" {
  value = var.redshift_database_name
}

output "redshift_admin_username" {
  value = var.redshift_admin_username
}

output "redshift_admin_password" {
  description = "Generated admin password"
  value       = random_password.redshift_admin.result
  sensitive   = true
}

output "glue_database_name" {
  value = aws_glue_catalog_database.raw.name
}

output "glue_crawler_name" {
  value = aws_glue_crawler.raw_data.name
}

output "redshift_workgroup_name" {
  value = aws_redshiftserverless_workgroup.main.workgroup_name
}

output "redshift_spectrum_role_arn" {
  value = aws_iam_role.redshift_spectrum.arn
}
