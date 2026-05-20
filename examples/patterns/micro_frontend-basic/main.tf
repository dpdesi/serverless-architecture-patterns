provider "aws" {
  region = "eu-west-2"
}

module "micro_frontend" {
  source = "../../../modules/patterns/micro_frontend"

  name = "example-micro-frontend"
  deployer_artefact = {
    s3_bucket = "example-artefacts"
    s3_key    = "manifest-deployer.zip"
  }

  tags = {
    Environment = "dev"
    System      = "example"
    Owner       = "platform"
  }
}

output "manifest_bucket_name" {
  value = module.micro_frontend.bucket_name
}

output "deployer_function_name" {
  value = module.micro_frontend.deployer_function_name
}
