package terraform.s3

import future.keywords.if

deny[msg] if {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_public_access_block"
  after := resource.change.after
  not after.block_public_acls
  msg := sprintf("%s must block public ACLs", [resource.address])
}

deny[msg] if {
  resource := input.resource_changes[_]
  resource.type == "aws_s3_bucket_public_access_block"
  after := resource.change.after
  not after.block_public_policy
  msg := sprintf("%s must block public bucket policies", [resource.address])
}
