terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "email" {
  description = "Email for SNS notifications"
  default     = "kampai1573@gmail.com" # for the mail where we want to receive notifications
}

# Random suffix to avoid naming conflicts
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Secrets Manager: Create a secret
resource "aws_secretsmanager_secret" "top_secret" {
  name        = "top-secret-info-${random_string.suffix.result}"
  description = "Test secret for monitoring access"
}

resource "aws_secretsmanager_secret_version" "top_secret_version" {
  secret_id     = aws_secretsmanager_secret.top_secret.id
  secret_string = jsonencode({ "secret" = "I need three coffees a day to function" })
}

# S3 Bucket for CloudTrail logs
resource "aws_s3_bucket" "trail_bucket" {
  bucket = "secrets-manager-trail-${random_string.suffix.result}"
}

resource "aws_s3_bucket_ownership_controls" "trail_bucket_ownership" {
  bucket = aws_s3_bucket.trail_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "trail_bucket_acl" {
  bucket     = aws_s3_bucket.trail_bucket.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.trail_bucket_ownership]
}

# S3 Bucket Policy for CloudTrail
resource "aws_s3_bucket_policy" "trail_bucket_policy" {
  bucket = aws_s3_bucket.trail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail_bucket.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail_bucket.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
  depends_on = [aws_s3_bucket_acl.trail_bucket_acl]
}

# CloudWatch: Log group for CloudTrail
resource "aws_cloudwatch_log_group" "secrets_log_group" {
  name              = "/aws/cloudtrail/secrets-manager-log-group"
  retention_in_days = 7 # Free Tier compatible
}

# CloudTrail: Track management events (including Secrets Manager)
resource "aws_cloudtrail" "secrets_trail" {
  name                          = "secrets-manager-trail-${random_string.suffix.result}"
  s3_bucket_name                = aws_s3_bucket.trail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.secrets_log_group.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_role.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket.trail_bucket, aws_s3_bucket_policy.trail_bucket_policy, aws_cloudwatch_log_group.secrets_log_group]
}

# CloudWatch: Metric filter for secret access
resource "aws_cloudwatch_log_metric_filter" "secret_access_filter" {
  name           = "get-secrets-value"
  pattern        = "{ $.eventName = \"GetSecretValue\" }"
  log_group_name = aws_cloudwatch_log_group.secrets_log_group.name

  metric_transformation {
    name          = "SecretIsAccessed"
    namespace     = "SecurityMetrics"
    value         = "1"
    default_value = "0"
  }
}

# CloudWatch: Alarm for secret access
resource "aws_cloudwatch_metric_alarm" "secret_access_alarm" {
  alarm_name          = "secret-was-accessed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SecretIsAccessed"
  namespace           = "SecurityMetrics"
  period              = 60 # 1 minute
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alarm when secret is accessed"
  alarm_actions       = [aws_sns_topic.security_alarms.arn]
  treat_missing_data  = "notBreaching"
}

# SNS: Topic and subscription
resource "aws_sns_topic" "security_alarms" {
  name = "security-alarms-${random_string.suffix.result}"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.security_alarms.arn
  protocol  = "email"
  endpoint  = var.email
}

# IAM: Role for CloudTrail to write to CloudWatch
resource "aws_iam_role" "cloudtrail_role" {
  name = "cloudtrail-to-cloudwatch-role-${random_string.suffix.result}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_policy" {
  name = "cloudtrail-to-cloudwatch-policy"
  role = aws_iam_role.cloudtrail_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.secrets_log_group.arn}:*"
      }
    ]
  })
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# Output secret name for Boto3
output "secret_name" {
  value = aws_secretsmanager_secret.top_secret.name
}