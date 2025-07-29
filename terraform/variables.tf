# Variable definitions for OpenTofu/Terraform configuration

variable "ubuntu_instance_count" {
  description = "Number of Ubuntu monitoring instances to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.ubuntu_instance_count >= 1 && var.ubuntu_instance_count <= 10
    error_message = "Ubuntu instance count must be between 1 and 10."
  }
}

variable "filebeat_host" {
  description = "Hostname or IP address of Filebeat server"
  type        = string
  default     = "filebeat"
}

variable "filebeat_port" {
  description = "Port number for Filebeat server"
  type        = number
  default     = 5000
  
  validation {
    condition     = var.filebeat_port > 0 && var.filebeat_port <= 65535
    error_message = "Filebeat port must be a valid port number (1-65535)."
  }
}

variable "environment" {
  description = "Environment name for resource tagging"
  type        = string
  default     = "development"
  
  validation {
    condition = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "project_name" {
  description = "Name of the project for resource naming and tagging"
  type        = string
  default     = "infrastructure-monitoring"
}

variable "ubuntu_image_version" {
  description = "Ubuntu Docker image version to use"
  type        = string
  default     = "24.04"
}

variable "container_memory_limit" {
  description = "Memory limit for Ubuntu containers in MB"
  type        = number
  default     = 512
  
  validation {
    condition     = var.container_memory_limit >= 128 && var.container_memory_limit <= 2048
    error_message = "Container memory limit must be between 128 MB and 2048 MB."
  }
}

variable "enable_healthcheck" {
  description = "Enable health checks for created containers"
  type        = bool
  default     = true
}

variable "restart_policy" {
  description = "Restart policy for containers"
  type        = string
  default     = "unless-stopped"
  
  validation {
    condition = contains(["no", "always", "unless-stopped", "on-failure"], var.restart_policy)
    error_message = "Restart policy must be one of: no, always, unless-stopped, on-failure."
  }
}
