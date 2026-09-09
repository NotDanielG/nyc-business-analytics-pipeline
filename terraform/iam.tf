data "aws_iam_policy_document" "data_lake_access" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.data_lake.arn]
  }

  statement {
    sid    = "ReadWriteObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.data_lake.arn}/*"]
  }
}

resource "aws_iam_policy" "data_lake_access" {
  name        = "${var.project_name}-s3-access"
  description = "Read/write access to the ${var.data_bucket_name} bucket"
  policy      = data.aws_iam_policy_document.data_lake_access.json
}

data "aws_iam_policy_document" "pipeline_policy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipeline_execution" {
  name               = "${var.project_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.pipeline_policy_trust.json
}

resource "aws_iam_role_policy_attachment" "pipeline_execution_s3" {
  role       = aws_iam_role.pipeline_execution.name
  policy_arn = aws_iam_policy.data_lake_access.arn
}

resource "aws_iam_role_policy_attachment" "pipeline_execution_logs" {
  role       = aws_iam_role.pipeline_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_user" "local_dev" {
  name = "${var.project_name}-local-dev"
}

resource "aws_iam_user_policy_attachment" "local_dev_s3" {
  user       = aws_iam_user.local_dev.name
  policy_arn = aws_iam_policy.data_lake_access.arn
}

resource "aws_iam_access_key" "local_dev" {
  user = aws_iam_user.local_dev.name
}

data "aws_iam_policy_document" "redshift_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["redshift.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "redshift_spectrum" {
  name               = "${var.project_name}-redshift-spectrum-role"
  assume_role_policy = data.aws_iam_policy_document.redshift_trust.json
}

resource "aws_iam_role_policy_attachment" "redshift_s3" {
  role       = aws_iam_role.redshift_spectrum.name
  policy_arn = aws_iam_policy.data_lake_access.arn
}

data "aws_iam_policy_document" "redshift_glue_read" {
  statement {
    sid    = "GlueCatalogReadForSpectrum"
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
    ]
    resources = ["*"] # Glue's resource-level permissions for these actions don't support scoping to one database
  }
}

resource "aws_iam_policy" "redshift_glue_read" {
  name        = "${var.project_name}-redshift-glue-read"
  description = "Read-only Glue Catalog access for Redshift Spectrum"
  policy      = data.aws_iam_policy_document.redshift_glue_read.json
}

resource "aws_iam_role_policy_attachment" "redshift_glue" {
  role       = aws_iam_role.redshift_spectrum.name
  policy_arn = aws_iam_policy.redshift_glue_read.arn
}

data "aws_iam_policy_document" "glue_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_crawler" {
  name               = "${var.project_name}-glue-crawler-role"
  assume_role_policy = data.aws_iam_policy_document.glue_trust.json
}

resource "aws_iam_role_policy_attachment" "glue_crawler_s3" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = aws_iam_policy.data_lake_access.arn
}

resource "aws_iam_role_policy_attachment" "glue_crawler_service_role" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}
