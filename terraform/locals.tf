locals {
  # Every AWS resource name (and the state file key, set at `terraform init`
  # time in CI) derives from this, so dev and prod never collide and never
  # need manual coordination when a new resource is added.
  name = "${var.function_name}-${var.environment}"
}
