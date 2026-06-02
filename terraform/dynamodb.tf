# Resumes table
#
# Access patterns:
#   GetResume(id)            → GetItem on PK=id
#   CreateResume / Update    → PutItem on PK=id
#   DeleteResume(id)         → DeleteItem on PK=id
#   ListResumes(userId)      → Query on userId-createdAt-index GSI

resource "aws_dynamodb_table" "resumes" {
  name         = "cvfit-resumes-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-createdAt-index"
    hash_key        = "userId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "cvfit-resumes-${var.environment}"
  }
}
