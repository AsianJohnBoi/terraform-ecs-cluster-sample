variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "ecs_task_cpu" {
  type = number
  default = 512
}

variable "ecs_task_memory" {
  type = number
  default = 1024
}

variable "ecs_task_name" {
  type = string
}

variable "ecs_task_image" {
  type = string
}

variable "ecs_task_port" {
  type = number
  default = 80
}

variable "ecs_service_count" {
  type = number
  default = 1
}

variable "ecs_service_subnets" {
  type = list(string)
}

variable "ecs_service_sg" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}