# this creates the bucket. Kept in a separate file so you can easily remove it from the plan when you want to clean up
resource "aws_s3_bucket" "storage" {
  bucket = "${local.destination_bucket}"
  acl    = "private"
}