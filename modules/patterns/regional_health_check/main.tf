locals {
  effective_threshold = coalesce(var.child_health_threshold, length(var.metric_alarms))
}

resource "aws_cloudwatch_metric_alarm" "child" {
  for_each = var.metric_alarms

  alarm_name          = "${var.name}-${each.key}"
  alarm_description   = coalesce(each.value.description, "${each.value.namespace}/${each.value.metric_name} health probe for ${var.name}.")
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  unit                = each.value.unit
  treat_missing_data  = var.treat_missing_data
  dimensions          = each.value.dimensions
  tags                = var.tags
}

resource "aws_cloudwatch_composite_alarm" "regional" {
  alarm_name        = "${var.name}-regional"
  alarm_description = "Composite regional health alarm for ${var.name}. Fires when any constituent service alarm is breaching."
  alarm_rule        = join(" OR ", [for key in sort(keys(aws_cloudwatch_metric_alarm.child)) : "ALARM(\"${aws_cloudwatch_metric_alarm.child[key].alarm_name}\")"])
  alarm_actions     = var.alarm_actions
  ok_actions        = var.ok_actions
  tags              = var.tags
}

resource "aws_route53_health_check" "child" {
  for_each = aws_cloudwatch_metric_alarm.child

  type                            = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name           = each.value.alarm_name
  cloudwatch_alarm_region         = var.region
  insufficient_data_health_status = "LastKnownStatus"

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
  })
}

resource "aws_route53_health_check" "regional" {
  type                            = "CALCULATED"
  child_health_threshold          = local.effective_threshold
  child_healthchecks              = [for hc in aws_route53_health_check.child : hc.id]
  invert_healthcheck              = var.inverted
  insufficient_data_health_status = "LastKnownStatus"

  tags = merge(var.tags, {
    Name = "${var.name}-regional"
  })
}
