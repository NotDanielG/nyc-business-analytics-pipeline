resource "aws_glue_catalog_database" "raw" {
  name = var.glue_database_name
}

resource "aws_glue_crawler" "raw_data" {
  name          = "${var.project_name}-raw-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.raw.name

  s3_target {
    path = "s3://${var.data_bucket_name}/${var.s3_raw_folder}/${var.s3_issued_license_folder_name}/"
  }

  s3_target {
    path = "s3://${var.data_bucket_name}/${var.s3_raw_folder}/${var.s3_311_folder_name}/"
  }

  s3_target {
    path = "s3://${var.data_bucket_name}/${var.s3_raw_folder}/${var.s3_pluto_folder_name}/"
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}
