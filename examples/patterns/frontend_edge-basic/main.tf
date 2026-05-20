provider "aws" {
  # CloudFront and ACM are global but the provider must target us-east-1 for
  # certificates and OAC management.
  region = "us-east-1"
}

module "frontend_edge" {
  source = "../../../modules/patterns/frontend_edge"

  name = "example-frontend-edge"

  api_origin = {
    domain_name  = "api.example.com"
    path_pattern = "/api/*"
  }

  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "distribution_domain_name" {
  value = module.frontend_edge.distribution_domain_name
}

output "primary_origin_bucket_id" {
  value = module.frontend_edge.primary_origin_bucket_id
}
