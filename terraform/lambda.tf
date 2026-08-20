# Package the Lambda source into a zip for deployment.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda_function.py"
  output_path = "${path.module}/build/lambda_function.zip"
}

# Least-privilege execution role — trusts only the Lambda service.
resource "aws_iam_role" "lambda_exec" {
  name = "${var.function_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Scoped logging permissions — this function's own log group only, never "*".
resource "aws_iam_role_policy" "lambda_logging" {
  name = "${var.function_name}-logging-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
      }
    ]
  })
}

# X-Ray write permissions for tracing (CKV_AWS_50). AWS requires Resource "*"
# for these two specific actions — there is no ARN to scope to; this is a
# documented AWS platform constraint, not an over-broad grant.
resource "aws_iam_role_policy" "lambda_xray" {
  name = "${var.function_name}-xray-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# Log group created explicitly (not auto-created by Lambda) so we control
# retention and naming — short retention keeps cost near zero.
# Customer-managed KMS intentionally omitted for lab cost control — same
# justification as the CKV_AWS_158 skip below.
#trivy:ignore:AVD-AWS-0017
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  # checkov:skip=CKV_AWS_158: Customer-managed KMS key intentionally omitted
  # to keep this lab at zero cost (CMKs incur a monthly charge). CloudWatch
  # Logs remain encrypted at rest by AWS-owned keys by default.
  # checkov:skip=CKV_AWS_338: 1-year retention intentionally NOT used — this
  # project's own design goal (see PORTFOLIO.md / project instructions) is
  # short log retention to keep a lab environment cheap and clean. Not a
  # production posture; a real production Lambda would use a longer window.
}

resource "aws_lambda_function" "app" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10
  memory_size = 128

  # Caps concurrent executions as a cost/blast-radius safeguard. This is
  # distinct from *provisioned* concurrency (which keeps instances warm and
  # bills continuously) — this is a free ceiling on simultaneous invocations.
  reserved_concurrent_executions = 5

  tracing_config {
    mode = "Active"
  }

  # checkov:skip=CKV_AWS_117: No VPC by design. Placing this Lambda in a VPC
  # would require a NAT Gateway (or VPC endpoints) for outbound access to
  # AWS APIs — exactly the cost/complexity this project's instructions say
  # to avoid. This function reaches no VPC-only resources (no RDS, no
  # private services), so there is nothing a VPC would protect here.
  # checkov:skip=CKV_AWS_116: No Dead Letter Queue by design. DLQs catch
  # failures from *asynchronous* invocations (SNS/S3/EventBridge triggers).
  # This function is only ever invoked synchronously via direct CLI/SDK
  # calls in this lab, so there is no async failure for a DLQ to capture.
  # checkov:skip=CKV_AWS_272: Code signing intentionally omitted. AWS Signer
  # profiles add real supply-chain integrity value in a multi-team
  # production pipeline, but are disproportionate setup overhead for a
  # single-developer lab. Called out here as a genuine production
  # recommendation, not overlooked.

  depends_on = [aws_cloudwatch_log_group.lambda_logs]
}
