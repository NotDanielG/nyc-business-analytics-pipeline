resource "random_password" "redshift_admin" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>?"
}

resource "aws_redshiftserverless_namespace" "main" {
  namespace_name       = "${var.project_name}-ns"
  db_name              = var.redshift_database_name
  admin_username       = var.redshift_admin_username
  admin_user_password  = random_password.redshift_admin.result
  iam_roles            = [aws_iam_role.redshift_spectrum.arn]
  default_iam_role_arn = aws_iam_role.redshift_spectrum.arn
}

resource "aws_redshiftserverless_workgroup" "main" {
  namespace_name      = aws_redshiftserverless_namespace.main.namespace_name
  workgroup_name      = "${var.project_name}-wg"
  base_capacity       = var.redshift_base_capacity
  publicly_accessible = true
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.redshift.id]
}
