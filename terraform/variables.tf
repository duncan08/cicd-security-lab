variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "cicd-security-lab-fn"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period, kept short to control cost"
  type        = number
  default     = 3
}
