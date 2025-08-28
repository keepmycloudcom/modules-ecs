### Variables
variable "name" { type = string }
variable "capacity_providers" { type = list(string) }
variable "tags" { type = map(string) }

### ECS
resource "aws_ecs_cluster" "main" {
  name = "${var.name}-ecs"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-ecs"
  })
}


#resource "aws_ecs_cluster_capacity_providers" "main" {
#  cluster_name = aws_ecs_cluster.main.name
#  capacity_providers = var.capacity_providers
  
#  default_capacity_provider_strategy {
#    base              = 1
#    weight            = 100
#    capacity_provider = "EXTERNAL"
#  }
#}


### Outputs
output "id" { value = aws_ecs_cluster.main.id }
output "arn" { value = aws_ecs_cluster.main.arn }
output "cluster_name" { value = aws_ecs_cluster.main.name }

# vim:filetype=terraform ts=2 sw=2 et:
