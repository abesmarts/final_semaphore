terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "docker" {}

# --------------------------------------------------
# Docker network
# --------------------------------------------------
resource "docker_network" "monitoring" {
  name   = "monitoring-network"
  driver = "bridge"

  ipam_config {
    subnet  = "172.20.0.0/16"
    gateway = "172.20.0.1"
  }

  labels {
    label = "project"
    value = "infrastructure-monitoring"
  }
  labels {
    label = "environment"
    value = "development"
  }
}

# --------------------------------------------------
# Docker volumes
# --------------------------------------------------
resource "docker_volume" "monitoring_data" {
  name = "monitoring-data"

  labels {
    label = "project"
    value = "infrastructure-monitoring"
  }
  labels {
    label = "type"
    value = "data-storage"
  }
}

resource "docker_volume" "shared_scripts" {
  name = "shared-scripts"

  labels {
    label = "project"
    value = "infrastructure-monitoring"
  }
  labels {
    label = "type"
    value = "script-storage"
  }
}

# --------------------------------------------------
# Ubuntu image
# --------------------------------------------------
resource "docker_image" "ubuntu" {
  name         = "ubuntu:24.04"
  keep_locally = true
}

# --------------------------------------------------
# Ubuntu monitoring containers
# --------------------------------------------------
resource "docker_container" "ubuntu_monitor" {
  count    = 2
  name     = "ubuntu-monitor-${count.index + 1}"
  image    = docker_image.ubuntu.latest
  hostname = "monitor-${count.index + 1}"
  restart  = "unless-stopped"

  command = ["tail", "-f", "/dev/null"]

  memory      = 512 * 1024 * 1024      # 512 MB
  memory_swap = 1024 * 1024 * 1024     # 1 GB

  networks_advanced {
    name         = docker_network.monitoring.name
    ipv4_address = "172.20.1.${count.index + 10}"
  }

  # Bind-mount project scripts (read-only) and attach data volume
  mounts {
    target    = "/opt/monitoring-scripts"
    source    = abspath("${path.module}/../python-scripts")
    type      = "bind"
    read_only = true
  }

  mounts {
    target = "/opt/monitoring-data"
    source = docker_volume.monitoring_data.name
    type   = "volume"
  }

  env = [
    "LOGSTASH_HOST=logstash",
    "LOGSTASH_PORT=5000",
    "INSTANCE_ID=${count.index + 1}",
    "ENVIRONMENT=development"
  ]

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

  healthcheck {
    test     = ["CMD", "bash", "-c", "sleep 5 || exit 0"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
  }
}
