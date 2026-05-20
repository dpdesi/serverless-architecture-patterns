package terraform.iam

import future.keywords.if
import future.keywords.in

policy_types := {
  "aws_iam_policy",
  "aws_iam_role_policy",
}

deny[msg] if {
  resource := input.resource_changes[_]
  resource.type in policy_types
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  action := actions(statement)[_]
  action == "*"
  msg := sprintf("%s must not grant wildcard IAM actions", [resource.address])
}

deny[msg] if {
  resource := input.resource_changes[_]
  resource.type in policy_types
  policy := json.unmarshal(resource.change.after.policy)
  statement := policy.Statement[_]
  resource_arn := resources(statement)[_]
  resource_arn == "*"
  not allowed_global_action(statement)
  msg := sprintf("%s must not grant wildcard resources for service-scoped actions", [resource.address])
}

actions(statement) := result if {
  is_array(statement.Action)
  result := statement.Action
}

actions(statement) := [statement.Action] if {
  is_string(statement.Action)
}

resources(statement) := result if {
  is_array(statement.Resource)
  result := statement.Resource
}

resources(statement) := [statement.Resource] if {
  is_string(statement.Resource)
}

allowed_global_action(statement) if {
  action := actions(statement)[_]
  startswith(action, "logs:")
}

allowed_global_action(statement) if {
  action := actions(statement)[_]
  startswith(action, "xray:")
}
