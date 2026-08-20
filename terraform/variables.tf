variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Base name of the Lambda function — the environment suffix is appended automatically (see locals.tf), so this should NOT include \"-dev\" or \"-prod\"."
  type        = string
  default     = "cicd-security-lab-fn"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period, kept short to control cost"
  type        = number
  default     = 3
}

variable "environment" {
  description = "Deployment environment. Required (no default) so every plan/apply is explicit about its target — drives resource naming and keeps dev and prod fully isolated (separate function, role, and log group, separate Terraform state file)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either \"dev\" or \"prod\"."
  }
}
