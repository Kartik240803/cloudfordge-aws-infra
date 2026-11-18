variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "name" {
  type    = string
  default = "cloudfordge"
}

variable "owner" {
  description = "Value of the Owner tag applied to every taggable resource."
  type        = string
  default     = "Kartik Patel"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Exactly two availability zones are required."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "app_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.128.0/20", "10.0.144.0/20"]
}

variable "db_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.160.0/20", "10.0.176.0/20"]
}

variable "app_port" {
  type    = number
  default = 3005
}

variable "db_name" {
  type    = string
  default = "cloudprep"
}

variable "db_username" {
  type    = string
  default = "cloudfordge_admin"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_multi_az" {
  type    = bool
  default = true
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}

variable "secret_recovery_window_days" {
  description = "0 deletes the secret immediately on destroy so the name can be reused."
  type        = number
  default     = 0
}

variable "image_tag" {
  type    = string
  default = "v1"
}

variable "task_cpu" {
  type    = number
  default = 512
}

variable "task_memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  description = "Keep 0 on the first apply (no image exists yet). Set to 1 after the image is pushed and the migration task has run."
  type        = number
  default     = 0
}

variable "min_tasks" {
  type    = number
  default = 1
}

variable "max_tasks" {
  type    = number
  default = 3
}

variable "cpu_target_percent" {
  type    = number
  default = 60
}

variable "health_check_grace_seconds" {
  type    = number
  default = 90
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "domain_name" {
  description = "Public hostname (e.g. exam.example.com). When set, Terraform requests an ACM certificate (DNS validation), creates the Route 53 alias to the ALB, and enables HTTPS."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID that contains domain_name. Required when domain_name is set."
  type        = string
  default     = ""

  validation {
    condition     = var.domain_name == "" || var.hosted_zone_id != ""
    error_message = "hosted_zone_id is required when domain_name is set."
  }
}

variable "certificate_arn" {
  description = "Existing ACM certificate ARN, used only when domain_name is empty. Adds HTTPS :443 and redirects :80 to it."
  type        = string
  default     = ""
}

variable "app_url" {
  description = "Public URL for NEXTAUTH_URL and APP_URL. Defaults to https://domain_name, else the ALB DNS name over HTTP."
  type        = string
  default     = ""
}

variable "admin_email" {
  type    = string
  default = ""
}

variable "extra_environment" {
  description = "Additional plain environment variables (SMTP_HOST, SMTP_PORT, R2_BUCKET_NAME, ...)."
  type        = map(string)
  default     = {}
}

variable "extra_secret_keys" {
  description = "Additional keys that already exist in the Secrets Manager secret (SMTP_USER, SMTP_PASS, ...)."
  type        = list(string)
  default     = []
}

variable "github_repo_url" {
  description = "HTTPS URL of the GitHub repo. Empty skips creating the CodeBuild project."
  type        = string
  default     = ""
}

variable "github_branch" {
  type    = string
  default = "aws"
}

variable "force_https" {
  description = "Docker build arg FORCE_HTTPS (read by Next.js at build time)."
  type        = string
  default     = "false"
}

variable "alert_email" {
  description = "Email for alarm notifications. Empty creates the topic without a subscription."
  type        = string
  default     = ""
}
