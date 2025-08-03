terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = ">= 2.23.1"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_image" "ubuntu_with_ssh" {
  name = "ubuntu:22.04-ssh"
  build {
    context = "${path.module}"
    dockerfile = "Dockerfile"
  }
}



resource "docker_container" "ansible_vm1" {
  name  = "ansible-vm1"
  image = docker_image.ubuntu_with_ssh.image_id

  command = ["/usr/sbin/sshd", "-D"]

  ports {
    internal = 22
    external = 2222
  }

  env = [
    "DEBIAN_FRONTEND=noninteractive"
  ]

  labels {
    label = "filebeat_ingest"
    value = "true"
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.monitoring-network.name
  }

  rm = false
  restart = "unless-stopped"
}
