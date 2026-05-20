variable "name" {
  description = "Frontend edge name. Used to derive resource names and the OAC identifier."
  type        = string
}

variable "description" {
  description = "CloudFront distribution comment."
  type        = string
  default     = "Frontend edge managed by the serverless architecture patterns library."
}

variable "primary_origin_bucket_name" {
  description = "Optional override for the primary S3 origin bucket name. Defaults to `<name>-primary`."
  type        = string
  default     = null
}

variable "secondary_origin" {
  description = "Optional pre-existing secondary origin (typically an S3 bucket in another region) used as the failover origin in an origin group. Provide the regional domain name (e.g. `my-bucket.s3.us-west-2.amazonaws.com`) and an OAC ID created in this region. The caller is responsible for the bucket itself and its bucket policy."
  type = object({
    domain_name              = string
    origin_access_control_id = string
  })
  default = null
}

variable "failover_status_codes" {
  description = "HTTP status codes from the primary origin that trigger origin group failover to the secondary."
  type        = list(number)
  default     = [500, 502, 503, 504]

  validation {
    condition     = length(var.failover_status_codes) > 0
    error_message = "failover_status_codes must contain at least one HTTP status code."
  }
}

variable "api_origin" {
  description = "Optional API origin. When set, requests matching `path_pattern` are routed to the API target with caching disabled, host header stripped, and HTTPS-only origin protocol. Use this to surface a BFF at e.g. /api/* alongside the static SPA."
  type = object({
    domain_name  = string
    path_pattern = string
  })
  default = null

  validation {
    condition     = var.api_origin == null || try(can(regex("^/.+", var.api_origin.path_pattern)), false)
    error_message = "api_origin.path_pattern must be a CloudFront path pattern starting with '/' (e.g. '/api/*')."
  }
}

variable "default_root_object" {
  description = "Object returned when viewers request the distribution root URL. Typically `index.html` for SPAs."
  type        = string
  default     = "index.html"
}

variable "spa_error_responses" {
  description = "When true, 403 and 404 responses from the origin are rewritten to /index.html with a 200 status so an SPA can handle client-side routing."
  type        = bool
  default     = true
}

variable "domain_aliases" {
  description = "Custom DNS aliases for the distribution (CNAMEs). When set, `acm_certificate_arn` must also be provided."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for `domain_aliases`. Must live in us-east-1 because CloudFront only accepts certificates from that region."
  type        = string
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || can(regex("^arn:aws:acm:us-east-1:", var.acm_certificate_arn))
    error_message = "acm_certificate_arn must be an ACM certificate in us-east-1 (CloudFront constraint)."
  }
}

variable "minimum_protocol_version" {
  description = "Minimum viewer-to-CloudFront TLS protocol version."
  type        = string
  default     = "TLSv1.2_2021"
}

variable "viewer_protocol_policy" {
  description = "Default cache behaviour viewer protocol policy."
  type        = string
  default     = "redirect-to-https"

  validation {
    condition     = contains(["allow-all", "https-only", "redirect-to-https"], var.viewer_protocol_policy)
    error_message = "viewer_protocol_policy must be allow-all, https-only, or redirect-to-https."
  }
}

variable "price_class" {
  description = "CloudFront price class controlling the global edge footprint."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "web_acl_arn" {
  description = "Optional AWS WAFv2 web ACL ARN to attach to the distribution. Must be in scope CLOUDFRONT (us-east-1)."
  type        = string
  default     = null
}

variable "geo_restriction" {
  description = "Optional geo restriction. type must be `none`, `whitelist`, or `blacklist`."
  type = object({
    type      = string
    locations = optional(list(string), [])
  })
  default = {
    type      = "none"
    locations = []
  }

  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.geo_restriction.type)
    error_message = "geo_restriction.type must be none, whitelist, or blacklist."
  }
}

variable "access_log_bucket_domain_name" {
  description = "Optional bucket regional domain name (e.g. `logs.s3.amazonaws.com`) to deliver CloudFront access logs to. The bucket must have ACLs enabled and grant `awslogsdelivery` write access — CloudFront's logging stack predates OAC."
  type        = string
  default     = null
}

variable "access_log_prefix" {
  description = "Prefix within `access_log_bucket_domain_name` for this distribution's logs."
  type        = string
  default     = null
}

variable "create_kms_key" {
  description = "Whether to create a KMS key for the origin bucket. Set to false (and pass kms_key_arn) when the key is provided from a parent pattern or stack."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN to encrypt the primary origin bucket."
  type        = string
  default     = null
}

variable "tags" {
  description = "Required resource tags. Must include Environment, System, and Owner."
  type        = map(string)

  validation {
    condition = alltrue([
      contains(keys(var.tags), "Environment"),
      contains(keys(var.tags), "System"),
      contains(keys(var.tags), "Owner")
    ])
    error_message = "tags must include Environment, System, and Owner."
  }
}
