output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.this.arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "central_log_group_name" {
  description = "Name of the central CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.central.name
}

output "deny_unapproved_regions_policy_arn" {
  description = "ARN of the deny unapproved regions policy"
  value       = aws_iam_policy.deny_unapproved_regions.arn
}

output "deny_cloudtrail_disable_policy_arn" {
  description = "ARN of the deny CloudTrail disable policy"
  value       = aws_iam_policy.deny_cloudtrail_disable.arn
}

output "deny_public_s3_policy_arn" {
  description = "ARN of the deny public S3 policy"
  value       = aws_iam_policy.deny_public_s3.arn
}

output "guardrail_policy_arns" {
  description = "All guardrail policy ARNs for attachment"
  value = [
    aws_iam_policy.deny_unapproved_regions.arn,
    aws_iam_policy.deny_cloudtrail_disable.arn,
    aws_iam_policy.deny_public_s3.arn
  ]
}
