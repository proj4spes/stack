/**
 * The ALB module creates an ALB, security group
 * a route53 record and a service healthcheck.
 * It is used by the web-service module.
 */

variable "name" {
  description = "ALB name, e.g cdn"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs"
  type        = "list"
}


variable "region" {
  description = "region ehre to deploy, e.ig eu-west-1"
}
 
variable "certificate_arn" {
  description = "cert for  usually external alb"
}


variable "vpc_id" {
  description = "vpc_id for target group only usage- int comment"

}


variable "security_groups" {
  description = " list of security group IDs"
  #type = "list"
}

variable "healthcheck" {
  description = "Healthcheck path"
}

variable "log_bucket" {
  description = "S3 bucket name to write ALB logs into"
}

variable "log_prefix" {
  description = "S3 bucket prefix  where each ALB logs into"
}

variable "internal_dns_name" {
  description = "The subdomain under which the ALB is exposed internally, defaults to the task name"
}


variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}

#variable "ssl_certificate_id" {
#}

/**
 * Resources.
 */

module "alb" {
  source                        = "./terraform-aws-alb"
  alb_name                      = "${var.name}"
  region                        = "${ var.region}"
  alb_is_internal               = true
  alb_security_groups           = ["${var.security_groups}"]
  vpc_id                        = "${ var.vpc_id}"
  subnets                       = "${var.subnet_ids}"
  alb_protocols                 = ["HTTP"]
  certificate_arn               = "${var.certificate_arn}"
  create_log_bucket             = true
  enable_logging                = true
  log_bucket_name               = "${var.log_bucket}"
  log_location_prefix           = "${var.log_prefix}"
#to test force-destroy log
  force_destroy_log_bucket      = true
  health_check_path             = "${var.healthcheck}"

  tags {
    "Terraform" = "true"
    "Env"       = "${terraform.workspace}"
  }
}



resource "aws_route53_record" "internal" {
  zone_id = "${var.internal_zone_id}"
  name    = "${var.internal_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${module.alb.alb_zone_id}"
    name                   = "${module.alb.alb_dns_name}"

    evaluate_target_health = false
  }
}

/**
 * Outputs.
 */

// alb_lst_id to add other rules
output "alb_listener_http_arn" {
  value = "${module.alb.alb_listener_http_arn}"
}
// alb_lst_id to add other rules
output "alb_listener_https_arn" {
  value = "${module.alb.alb_listener_https_arn}"
}

// The ALB name.
#output "name" {
#  value = "${module.alb.alb_dns_name}"
#}

// The ALB ID.
output "id" {
  value = "${module.alb.alb_id}"
}

// The ALB dns_name.
output "dns" {
  value = "${module.alb.alb_dns_name}"
}


// FQDN built using the zone domain and name (internal)
output "internal_fqdn" {
  value = "${aws_route53_record.internal.fqdn}"
}

// The zone id of the ALB
output "zone_id" {
  value = "${module.alb.alb_zone_id}"
}

// The target group for alb
output "target_group_arn" {
  value = "${module.alb.target_group_arn}"
}
