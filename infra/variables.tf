variable "prefect_account_id" {
  type = string
}

variable "prefect_api_key" {
  type      = string
  sensitive = true
}

variable "prefect_workspace_id" {
  type = string
}

variable "account_number" {
  description = "AWS account number for the ECS task execution role"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "prefect_work_pool_name" {
  description = "Name of the Prefect work pool"
  type        = string
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
}

variable "docker_hub_username" {
  description = "Docker Hub username"
  type        = string
}

variable "docker_hub_password" {
  description = "Docker Hub password"
  type        = string
}
