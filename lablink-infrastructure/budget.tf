resource "aws_budgets_budget" "lablink_monthly" {
  count = try(local.config_file.monitoring.budget.enabled, false) ? 1 : 0

  name              = "lablink-monthly-budget-${var.resource_suffix}"
  budget_type       = "COST"
  limit_amount      = try(local.config_file.monitoring.budget.monthly_budget_usd, "100")
  limit_unit        = "USD"
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())
  time_unit         = "MONTHLY"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "user:Environment$${var.resource_suffix}",
      "user:ManagedBy$lablink-allocator-${var.resource_suffix}"
    ]
  }

  # 50% warning
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [local.config_file.monitoring.email]
  }

  # 80% urgent
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [local.config_file.monitoring.email]
  }

  # 100% critical
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [local.config_file.monitoring.email]
  }

  # 150% severe overage
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 150
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [local.config_file.monitoring.email]
  }

  tags = {
    Name        = "lablink-monthly-budget-${var.resource_suffix}"
    Environment = var.resource_suffix
  }
}