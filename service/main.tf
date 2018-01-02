/**
 * The service module creates an ecs service, task definition
 * elb and a route53 record under the local service zone (see the dns module).
 *
 * Usage:
 *
 *      module "auth_service" {
 *        source    = "github.com/segmentio/stack/service"
 *        name      = "auth-service"
 *        image     = "auth-service"
 *        cluster   = "default"
 *	  count     =  3
 *      }
 *
 */

/**
 * Required Variables.
 */


variable "region" {
  description = "region where to deploy tag, e.g eu-west-1"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "image" {
  description = "The docker image name, e.g nginx"
}

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
  default     = ""
}

variable "log_bucket" {
  description = "The log bucket name for elb classic solution - stack shared"
  default     = "log-bucket-elb-classic"
}

variable "version" {
  description = "The docker image version"
  default     = "latest"
}

variable "subnet_ids" {
  description = "list of subnet IDs that will be passed to the ELB module"
  type        = "list"
}

variable "security_groups" {
  description = "Comma separated list of security group IDs that will be passed to the ELB module"
}

variable "vpc_id" {
   description = "vpc_id for target group only usage- int comment"
 }

variable "port" {
  description = "The container internl host port"
}

variable "cluster" {
  description = "The cluster name or ARN"
}

variable "internal_dns_name" {
  description = "internal dns name for elb i.e. ngx.local.stack"
}

variable "internal_zone_id" {
  description = "The nternal zone id R53 the ELB"
}

variable "ssl_certificate_id" {
  description = "certificate for internal communication ... not usefulel now "
}
/**
 * Options.
 */

variable "healthcheck" {
  description = "Path to a healthcheck endpoint"
  default     = "/"
}

variable "container_port" {
  description = "The container port"
  default     = 3000
}

variable "command" {
  description = "The raw json of the task command"
  default     = "[]"
}

variable "env_vars" {
  description = "The raw json of the task env vars"
  default     = "[]"
}

variable "desired_count" {
  description = "The desired count"
  default     = 2
}

variable "memory" {
  description = "The number of MiB of memory to reserve for the container"
  default     = 512
}

variable "cpu" {
  description = "The number of cpu units to reserve for the container"
  default     = 512
}

variable "protocol" {
  description = "The ELB protocol, HTTP or TCP"
  default     = "HTTP"
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}


variable "deployment_minimum_healthy_percent" {
  description = "lower limit (% of desired_count) of # of running tasks during a deployment"
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "upper limit (% of desired_count) of # of running tasks during a deployment"
  default     = 200
}

/**
 * Resources.
 */

resource "aws_ecs_service" "main" {
  name                               = "${module.task.name}"
  cluster                            = "${var.cluster}"
  task_definition                    = "${module.task.arn}"
  desired_count                      = "${var.desired_count}"
  iam_role                           = "${var.iam_role}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"

  load_balancer {
 #   elb_name       = "${module.elb.id}"
    target_group_arn = "${module.alb_Idns.target_group_arn}"
    container_name = "${module.task.name}"
    container_port = "${var.container_port}"
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = ["null_resource.alb_listener_arn", "null_resource.alb_arn"]
}

resource "null_resource" "alb_listener_arn" {
  triggers {
    alb_listener_arn = "${module.alb_Idns.alb_listener_http_arn}"
  }
}

resource "null_resource" "alb_arn" {
  triggers {
    alb_name = "${module.alb_Idns.id}"
  }
}


resource "random_string" "tsk_name" {
  length = 3
  upper   = false
  number  = false
  special = false
  lower=true
}



module "task" {
  source = "../task"

  #name          = "${var.cluster}-${replace(var.image, "/", "-")}-${var.name}"
  name          = "${var.cluster}-${random_string.tsk_name.result}-${var.name}"
  image         = "${var.image}"
  image_version = "${var.version}"
  command       = "${var.command}"
  env_vars      = "${var.env_vars}"
  memory        = "${var.memory}"
  cpu           = "${var.cpu}"

      #  in PortMapping  do not use "hostPort": ${var.port}
  ports = <<EOF
  [
    {
      "containerPort": ${var.container_port}
    }
  ]
EOF
}


#module "elb" {
#  source = "../elb"
#
#  name            = "${module.task.name}"
#  port            = "${var.port}"
#  environment     = "${var.environment}"
#  subnet_ids      = "${var.subnet_ids}"
#  security_groups = "${var.security_groups}"
#  dns_name        = "${coalesce(var.dns_name, module.task.name)}"
#  healthcheck     = "${var.healthcheck}"
#  protocol        = "${var.protocol}"
#  zone_id         = "${var.zone_id}"
#  log_bucket      = "${var.log_bucket}"
#}

module "alb_Idns" {
  source             = "./alb"
  name               = "${module.task.name}"
  region             = "${ var.region}"
  security_groups    = "${var.security_groups}"
  vpc_id             = "${ var.vpc_id}"
  subnet_ids         = "${var.subnet_ids}"
  certificate_arn    = "${var.ssl_certificate_id}"
  #log_bucket         = "${var.log_bucket}-${var.name}"
  #log_bucket         = "${var.cluster}-${var.name}"
    log_bucket         = "${format("%.6s-%.2s-%.8s-%.3s",var.cluster,var.environment,var.name,random_string.tsk_name.result)}"
  # add a prefix to differentiate albs per services
  log_prefix         = "I"
  healthcheck        = "${var.healthcheck}"
  internal_dns_name  = "${coalesce(var.internal_dns_name, module.task.name)}"
  internal_zone_id   = "${var.internal_zone_id}"

}

/**
 * Outputs.
 */

#// The name of the ELB
#output "name" {
#   value = "${module.elb.name}"
#}

// The DNS name of the ELB
output "dns" {
  value = "${module.alb_Idns.dns}"
}

// The id of the ELB
output "alb" {
  value = "${module.alb_Idns.id}"
}

// The zone id of the ELB
output "zone_id" {
  value = "${module.alb_Idns.zone_id}"
}

// FQDN built using the zone domain and name
output "fqdn" {
  value = "${module.alb_Idns.internal_fqdn}"
}

// listener http id
output "listener_http_arn" {
   value = "${module.alb_Idns.alb_listener_http_arn}"
}

