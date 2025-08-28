### Variables
variable "aws_region" { type = string }
variable "name" { type = string }
variable "basename" { type = string }
variable "tags" { default = {} }
variable "project_env" { type = string }
variable "container_name" {
  default = ""
  type    = string
}
variable "task_container_image" { type = string }
variable "network_mode" { type = string }
variable "credentials_parameter" { 
  type = string 
  default = ""
}
variable "container_port_mappings" {
  type = list(object({
    hostPort      = number
    containerPort = number
    protocol      = string
  }))
  default = []
}
variable "task_definition_cpu" {
  default = 256
  type    = number
}
variable "task_definition_memory" {
  default = 512
  type    = number
}
variable "task_container_cpu" {
  default = null
  type    = number
}
variable "task_container_memory" {
  default = null
  type    = number
}
variable "task_container_memory_reservation" {
  default = null
  type    = number
}
variable "task_container_command" {
  default = []
  type    = list(string)
}
variable "task_container_working_directory" {
  default = ""
  type    = string
}
variable "task_container_environment" {
  default = {}
  type    = map(string)
}
variable "cloudwatch_log_group_name" {
  type    = string
  default = ""
}
variable "placement_constraints" {
  type    = list
  default = []
}
variable "add_linux_parameters" {
  type    = list
  default = []
}
variable "drop_linux_parameters" {
  type    = list
  default = []
}
variable "system_controls" {
  default = []
  type    = list
}
variable "volumes_from" {
  default = []
  type    = list
}
variable "proxy_configuration" {
  type    = list
  default = []
}

variable "volume" { default = [] }
variable "task_health_check" {
  type    = object({ command = list(string), interval = number, timeout = number, retries = number, startPeriod = number })
  default = null
}
variable "task_start_timeout" {
  type    = number
  default = null
}
variable "task_stop_timeout" {
  type    = number
  default = null
}
variable "privileged" {
  type    = bool
  default = false
}
variable "task_mount_points" {
  type    = list(object({ sourceVolume = string, containerPath = string, readOnly = bool }))
  default = null
}
variable "docker_labels" {
  type    = map(string)
  default = null
}
variable "task_environment" { 
  type    = list(object({ name = string, value = string }))
  default = [{ name = "test", value = "test"}]
}

### Execution IAM Role
resource "aws_iam_role" "execution" {
  name = "${var.basename}-${var.name}-Execution-Role"

  assume_role_policy = <<-EOF
    {
      "Version": "2008-10-17",
      "Statement": [
        {
          "Sid": "",
          "Effect": "Allow",
          "Principal": {
            "Service": "ecs-tasks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    EOF

  tags = merge(var.tags, {
    name = "${var.basename}-${var.name}-Execution-Role"
  })
}

# Policy Attachment: Attach AmazonECSTaskExecutionRolePolicy to Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "secretsmanager" {
  statement {
    sid       = "kmc"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
  }
  statement {
    sid       = "secretsmanager"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ecr" {
  statement {
    sid       = "ecr"
    effect    = "Allow"
    actions   = ["ecr:batchGetImage"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "secret" {
  name        = "${var.basename}-${var.name}-secret-policy"
  description = "A Secret manager policy"
  policy      = data.aws_iam_policy_document.secretsmanager.json
}

resource "aws_iam_policy" "ecr" {
  name        = "${var.basename}-${var.name}-ecr-policy"
  description = "A ECR policy"
  policy      = data.aws_iam_policy_document.ecr.json
}

resource "aws_iam_role_policy_attachment" "secret" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.secret.arn
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.ecr.arn
}

### Task IAM Role
resource "aws_iam_role" "task" {
  name = "${var.basename}-${var.name}-Task-Role"

  assume_role_policy = <<-EOF
    {
      "Version": "2008-10-17",
      "Statement": [
        {
          "Sid": "",
          "Effect": "Allow",
          "Principal": {
            "Service": "ecs-tasks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    EOF

  tags = merge(var.tags, {
    name = "${var.basename}-${var.name}-Task-Role"
  })
}

# IAM Policy: allow to CloudWatch Logs
resource "aws_iam_role_policy" "log_agent" {
  name = "${var.basename}-${var.name}-log-permissions"
  role = aws_iam_role.task.id

  policy = <<-EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": "*"
        }
      ]
    }
    EOF
}

### Task
resource "aws_ecs_task_definition" "task" {
  family                   = "${var.basename}-${var.name}"
  execution_role_arn       = aws_iam_role.execution.arn
  network_mode             = "${var.network_mode}"
  requires_compatibilities = ["EXTERNAL"]
  cpu                      = var.task_definition_cpu
  memory                   = var.task_definition_memory
  task_role_arn            = aws_iam_role.task.arn
  container_definitions = <<EOF
    [{
        "name": "${var.container_name}",
        "image": "${var.task_container_image}",
        %{if var.credentials_parameter != ""~}
        "repositoryCredentials": {
            "credentialsParameter": "${var.credentials_parameter}"
        },
        %{~endif}
        "hostname": "${var.container_name}",
        "portMappings": ${jsonencode(var.container_port_mappings)},
        "essential": true,
        "systemControls": ${jsonencode(var.system_controls)},
        "volumesFrom": ${jsonencode(var.volumes_from)},
        "privileged": ${var.privileged},
        "linuxParameters": {
          "capabilities": {
            "add": ${jsonencode(var.add_linux_parameters)},
            "drop": ${jsonencode(var.drop_linux_parameters)}
          }
        },
        %{if var.cloudwatch_log_group_name != ""~}
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${var.cloudwatch_log_group_name}",
            "awslogs-region": "${var.aws_region}",
            "awslogs-stream-prefix": "${var.project_env}"
          }
        },
        %{~endif}
        %{if var.task_health_check != null~}
        "healthcheck": {
            "command": ${jsonencode(var.task_health_check.command)},
            "interval": ${var.task_health_check.interval},
            "timeout": ${var.task_health_check.timeout},
            "retries": ${var.task_health_check.retries},
            "startPeriod": ${var.task_health_check.startPeriod}
        },
        %{~endif}
        "command": ${jsonencode(var.task_container_command)},
        %{if var.task_container_working_directory != ""~}
        "workingDirectory": ${var.task_container_working_directory},
        %{~endif}
        %{if var.task_container_memory != null~}
        "memory": ${var.task_container_memory},
        %{~endif}
        %{if var.task_container_memory_reservation != null~}
        "memoryReservation": ${var.task_container_memory_reservation},
        %{~endif}
        %{if var.task_container_cpu != null~}
        "cpu": ${var.task_container_cpu},
        %{~endif}
        %{if var.task_start_timeout != null~}
        "startTimeout": ${var.task_start_timeout},
        %{~endif}
        %{if var.docker_labels != null~}
        "dockerLabels": ${jsonencode(var.docker_labels)},
        %{~endif}
        %{if var.task_stop_timeout != null~}
        "stopTimeout": ${var.task_stop_timeout},
        %{~endif}
        %{if var.task_mount_points != null~}
        "mountPoints": ${jsonencode(var.task_mount_points)},
        %{~endif}
        %{if var.task_environment  != null~}
        "environment": ${jsonencode(var.task_environment)}
        %{~endif}
    }]
    EOF

  dynamic "volume" {
    for_each = var.volume
    content {
      host_path = lookup(volume.value, "host_path", null)
      name      = volume.value.name

      dynamic "docker_volume_configuration" {
        for_each = lookup(volume.value, "docker_volume_configuration", [])
        content {
          autoprovision = lookup(docker_volume_configuration.value, "autoprovision", null)
          driver        = lookup(docker_volume_configuration.value, "driver", null)
          driver_opts   = lookup(docker_volume_configuration.value, "driver_opts", null)
          labels        = lookup(docker_volume_configuration.value, "labels", null)
          scope         = lookup(docker_volume_configuration.value, "scope", null)
        }
      }
      dynamic "efs_volume_configuration" {
        for_each = lookup(volume.value, "efs_volume_configuration", [])
        content {
          file_system_id = lookup(efs_volume_configuration.value, "file_system_id", null)
          root_directory = lookup(efs_volume_configuration.value, "root_directory", null)
        }
      }
    }
  }
  dynamic "placement_constraints" {
    for_each = var.placement_constraints
    content {
      expression = lookup(placement_constraints.value, "expression", null)
      type       = placement_constraints.value.type
    }
  }

  dynamic "proxy_configuration" {
    for_each = var.proxy_configuration
    content {
      container_name = proxy_configuration.value.container_name
      properties     = lookup(proxy_configuration.value, "properties", null)
      type           = lookup(proxy_configuration.value, "type", null)
    }
  }

  tags = merge(var.tags, {
    Name = "${var.basename}-${var.name}-ecs"
  })
}

### Outputs
output "task_role" {
  value = {
    id  = aws_iam_role.task.id
    arn = aws_iam_role.task.arn
    name = aws_iam_role.task.name
  }
}

output "arn" { value = aws_ecs_task_definition.task.arn }
output "family" { value = aws_ecs_task_definition.task.family }

# vim:filetype=terraform ts=2 sw=2 et:
