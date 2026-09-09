resource "aws_s3_bucket" "data_lake" {
  bucket = var.data_bucket_name
}

resource "aws_s3_bucket_versioning" "s3_versioning" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_access_block" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "prefixes" {
  for_each = toset(["raw/", "staging/", "marts/"])

  bucket  = aws_s3_bucket.data_lake.id
  key     = each.value
  content = ""
}
