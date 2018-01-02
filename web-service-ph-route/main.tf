/**
 * The web-service-ph- is similar to the `web.service` module, but the
 * it adds additional target groups/ecs service/ working on specific path route
 *
 * Usage:
 *
 *      module "ping-dummy-service2" {
 *        source    = "github.com/proj4spes/stack/service"
 *        name      = "service2"
 *        image     = "image_service2"
 *        iam_role  = "iam_role-ec2"
 *        cluster   = "default"
 *        port      = 80
 *        path_route= "/route_to_service2/*"
 *        priority  = 100
 *        count     = 3
 *      }
 *
 */

/**
 * Required Variables.
 */

variable "alb_listener_http_arn" {
  description = "Http listner's arn . Link to existing Alb listener."
}


variable "image" {
  description = "The docker image name, e.g nginx"
}

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
#  default     = ""
}

variable "version" {
  description = "The docker image version"
  default     = "latest"
}

variable "vpc_id" {
  description = "vpc_id for target group only usage- int comment"
  
}

variable "security_groups" {
  description = " list of security group IDs that will be passed to the ELB module"
  #type = "list"
}

variable "port" {
  description = "The container host port"
}

variable "cluster" {
  description = "The cluster name or ARN"
}



variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "path_route" {
  description = "path pattern route string. i.e sub-service in URL"
}

variable "priority" {
  description = "Rule priority for listener. nice to calculate"
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

resource "aws_alb_target_group" "alb_target" {

  name      = "${var.name}"
  port      = "${var.port}"
  protocol  = "HTTP"
  vpc_id    = "${var.vpc_id}"

health_check {
    healthy_threshold   = 2
    interval            = 15
    path                = "/"
    timeout             = 10
    unhealthy_threshold = 2
    matcher             = "200,202"
  }

}

resource "aws_ecs_service" "main" {
  name                               = "${module.task.name}"
  cluster                            = "${var.cluster}"
  task_definition                    = "${module.task.arn}"
  desired_count                      = "${var.desired_count}"
  iam_role                           = "${var.iam_role}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"

  load_balancer {
    target_group_arn = "${aws_alb_target_group.alb_target.arn}"
    container_name = "${module.task.name}"
    container_port = "${var.container_port}"
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = ["null_resource.alb_listener_arn"]
}

resource "null_resource" "alb_listener_arn" {
  triggers {
    alb_listener_arn = "${var.alb_listener_http_arn}"
  }
}


resource "random_string" "tsk_name" {
  length = 3
  upper   = false
  number  = false
  special = false
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

  # in port PortMapping    "hostPort": ${var.port}
  ports = <<EOF
  [
    {
      "containerPort": ${var.container_port} 
    }
  ]
EOF
}

   

resource "aws_alb_listener_rule" "path_route_rule" {
  listener_arn = "${var.alb_listener_http_arn}"
  priority     = "${var.priority}"

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.alb_target.arn}"
  }
condition {
    field = "path-pattern"
    values = ["${var.path_route}"]
  }

lifecycle {
    ignore_changes = ["priority"]
  }
}



/**
 * Outputs.
 */

output "listner_rule_id" {
   value = "${aws_alb_listener_rule.path_route_rule.id}"
}

output "ecs_service_id" {
   value = "${aws_ecs_service.main.id}"
}

output "target_group_id" {
   value = "${aws_alb_target_group.alb_target.id}"
}

output "task_arn" {
   value = "${module.task.arn}"
}
