### Variables
variable "aws_region" { type = string }
variable "name" { type = string }
variable "tags" { default = {} }
variable "project_env" { type = string }
variable "ecs_cluster" { type = string }
variable "ecs_task_definition" { type = string }
variable "scheduling_strategy"  { type = string }
variable "ecs_desired_count" { 
  default = 1
  type = string 
}
variable "ecs_launch_type" { 
  type = string 
  default = "EXTERNAL"
}

#variable "subnets" { type = list(string) }
#variable "vpc_id" { type = string }
variable "container_name" {
  default = ""
  type    = string
}
variable "container_port_mappings" {
  type = list(object({
    hostPort      = number
    containerPort = number
    protocol      = string
  }))
  default = []
}
variable "target_group" {
  default = ""
  type    = string
}
#variable "src_group" {
#  type    = string
#}

resource "aws_ecs_service" "main" {
  name            = "${var.name}"
  cluster         = "${var.ecs_cluster}"
  task_definition = "${var.ecs_task_definition}"
  desired_count   = "${var.ecs_desired_count}"
  launch_type     = "${var.ecs_launch_type}"
  scheduling_strategy = "${var.scheduling_strategy}"
#  lifecycle {
#    ignore_changes = all
#  }
}

# vim:filetype=terraform ts=2 sw=2 et:
