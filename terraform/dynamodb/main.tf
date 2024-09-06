# Note: We do not have to define all attributes (columns) while creating, we can add on-the-fly.

resource "aws_dynamodb_table" "projects" {
  name         = "projects"
  billing_mode = "PAY_PER_REQUEST" # alternative: PROVISIONED
  hash_key     = "id"
  range_key    = "created_at"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "title"
    type = "S"
  }

  attribute {
    name = "quality"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "QualityIndex"
    hash_key        = "quality"
    projection_type = "ALL" # all attributes from the table are projected into the index
  }

  global_secondary_index {
    name            = "TitleIndex"
    hash_key        = "title"
    projection_type = "ALL" # all attributes from the table are projected into the index
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = false
    # false -> use AWS Owned CMK | only free option
    # true -> use AWS Managed CMK
    # true + key arn -> use custom key
  }

  tags = {
    Name        = "dynamodb-table-for-projects"
    Environment = var.environment
  }
}
