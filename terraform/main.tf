# OpenTofu/Terraform configuration for virtual machine provisioning
terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Configure Docker provider
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Create a custom network for monitoring infrastructure
resource "docker_network" "monitoring_network" {
  name = "monitoring-network"
  driver = "bridge"
  
  ipam_config {
    subnet  = "172.20.0.0/16"
    gateway = "172.20.0.1"
  }
  
  labels = {
    project = "infrastructure-monitoring"
    environment = "development"
  }
}

# Ubuntu container for system monitoring
resource "docker_container" "ubuntu_monitor" {
  count = var.ubuntu_instance_count
  
  name  = "ubuntu-monitor-${count.index + 1}"
  image = docker_image.ubuntu.image_id
  
  # Keep container running
  command = ["tail", "-f", "/dev/null"]
  
  # Network configuration
  networks_advanced {
    name         = docker_network.monitoring_network.name
    ipv4_address = "172.20.1.${count.index + 10}"
  }
  
  # Volume mounts for script sharing
  volumes {
    host_path      = "${path.cwd}/../python-scripts"
    container_path = "/opt/monitoring-scripts"
    read_only      = true
  }
  
  # Environment variables
  env = [
    "LOGSTASH_HOST=${var.logstash_host}",
    "LOGSTASH_PORT=${var.logstash_port}",
    "INSTANCE_ID=${count.index + 1}",
    "ENVIRONMENT=development"
  ]
  
  # Resource limits
  memory = 512  # 512 MB
  memory_swap = 1024  # 1 GB swap
  
  # Labels for identification
  labels {
    label = "project"
    value = "infrastructure-monitoring"
  }
  
  labels {
    label = "role"
    value = "system-monitor"
  }
  
  labels {
    label = "instance"
    value = "${count.index + 1}"
  }
  
  # Health check
  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
  
  # Restart policy
  restart = "unless-stopped"
}

# Pull Ubuntu image
resource "docker_image" "ubuntu" {
  name = "ubuntu:24.04"
  keep_locally = true
}

# Create monitoring data volume
resource "docker_volume" "monitoring_data" {
  name = "monitoring-data"
  
  labels {
    project = "infrastructure-monitoring"
    type    = "data-storage"
  }
}

# Create shared scripts volume
resource "docker_volume" "shared_scripts" {
  name = "shared-scripts"
  
  labels {
    project = "infrastructure-monitoring"
    type    = "script-storage"
  }
}

# Output important information
output "ubuntu_instances" {
  description = "Information about created Ubuntu monitoring instances"
  value = {
    count = length(docker_container.ubuntu_monitor)
    instances = {
      for i, container in docker_container.ubuntu_monitor : 
      "instance-${i + 1}" => {
        name = container.name
        id   = container.id
        ip_address = container.networks_advanced[0].ipv4_address
      }
    }
  }
}

output "network_info" {
  description = "Monitoring network information"
  value = {
    name = docker_network.monitoring_network.name
    id   = docker_network.monitoring_network.id
    subnet = docker_network.monitoring_network.ipam_config[0].subnet
    gateway = docker_network.monitoring_network.ipam_config[0].gateway
  }
}

