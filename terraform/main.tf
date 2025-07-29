terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# --- Variables (declared inline for self-containment) ---

variable "ubuntu_instance_count" {
  description = "Number of Ubuntu monitoring containers to launch"
  type        = number
  default     = 2
}

variable "logstash_host" {
  description = "Logstash host (for env injection)"
  type        = string
  default     = "logstash"
}

variable "logstash_port" {
  description = "Logstash port (for env injection)"
  type        = string
  default     = "5000"
}

# --- Network ---

resource "docker_network" "monitoring_network" {
  name   = "monitoring-network"
  driver = "bridge"

  ipam_config {
    subnet  = "172.20.0.0/16"
    gateway = "172.20.0.1"
  }

  labels = {
    project     = "infrastructure-monitoring"
    environment = "development"
  }
}

# --- Volumes ---

resource "docker_volume" "monitoring_data" {
  name = "monitoring-data"
  labels = {
    project = "infrastructure-monitoring"
    type    = "data-storage"
  }
}

resource "docker_volume" "shared_scripts" {
  name = "shared-scripts"
  labels = {
    project = "infrastructure-monitoring"
    type    = "script-storage"
  }
}

# --- Ubuntu Image ---

resource "docker_image" "ubuntu" {
  name         = "ubuntu:24.04"
  keep_locally = true
}

# --- Ubuntu Containers ---

resource "docker_container" "ubuntu_monitor" {
  count    = var.ubuntu_instance_count
  name     = "ubuntu-monitor-${count.index + 1}"
  image    = docker_image.ubuntu.latest
  hostname = "monitor-${count.index + 1}"
  restart  = "unless-stopped"

  command = ["tail", "-f", "/dev/null"]

  memory      = 512 * 1024 * 1024       # 512 MB in bytes
  memory_swap = 1024 * 1024 * 1024      # 1 GB in bytes

  # Network configuration
  networks_advanced {
    name         = docker_network.monitoring_network.name
    ipv4_address = "172.20.1.${count.index + 10}"
  }

  # Volume mounts (use named Docker volumes AND a bind mount for scripts)
  volumes = [
    docker_volume.monitoring_data.name       # Example: can add :/data if you want a target path
  ]

  mounts {
    target = "/opt/monitoring-scripts"
    source = abspath("${path.module}/../python-scripts")
    type   = "bind"
    read_only = true
  }

  # Environment variables
  env = [
    "LOGSTASH_HOST=${var.logstash_host}",
    "LOGSTASH_PORT=${var.logstash_port}",
    "INSTANCE_ID=${count.index + 1}",
    "ENVIRONMENT=development"
  ]

  # Standard Docker labels (simple key-values)
  labels = {
    project  = "infrastructure-monitoring"
    role     = "system-monitor"
    instance = "${count.index + 1}"
  }

  # Health check
  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:8080/health"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}

# --- Outputs ---

output "ubuntu_instances" {
  description = "Info about Ubuntu monitoring containers"
  value = {
    count = length(docker_container.ubuntu_monitor)
    instances = {
      for i, c in docker_container.ubuntu_monitor :
      "instance-${i + 1}" => {
        name      = c.name
        id        = c.id
        ip_address = c.networks_advanced[0].ip_address
      }
    }
  }
}

output "network_info" {
  description = "Monitoring network information"
  value = {
    name    = docker_network.monitoring_network.name
    id      = docker_network.monitoring_network.id
    subnet  = docker_network.monitoring_network.ipam_config[0].subnet
    gateway = docker_network.monitoring_network.ipam_config[0].gateway
  }
}
