# NEGATIVE TEST FIXTURE — intentionally insecure Terraform.
#
# This file exists ONLY to prove Checkov/Trivy IaC scanning catches real
# misconfigurations. It is a standalone, never-initialized, never-applied
# configuration — it is NOT part of the terraform/ root module, is never
# referenced from deployable infrastructure, and these resources do not
# and must never exist in AWS.

resource "aws_s3_bucket" "insecure_example" {
  bucket = "cicd-lab-negative-test-bucket-example"
}

resource "aws_s3_bucket_acl" "insecure_example" {
  bucket = aws_s3_bucket.insecure_example.id
  acl    = "public-read"
}

resource "aws_iam_policy" "insecure_wildcard_policy" {
  name = "negative-test-overly-permissive-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "insecure_open_sg" {
  name        = "negative-test-open-sg"
  description = "Intentionally insecure — open to the world on all ports"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
