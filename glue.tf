
data aws_iam_policy_document glue_test_connection {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource aws_iam_role glue_test_connection {
  name               = "SARIGlueTestConnection"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.glue_test_connection.json
}

resource aws_iam_role_policy_attachment glue_service_role {
  role       = aws_iam_role.glue_test_connection.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

