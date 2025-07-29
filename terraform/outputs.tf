# Output definitions for OpenTofu/Terraform infrastructure

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
        status = container.status
        image = container.image
        created = container.created_at
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
    driver = docker_network.monitoring_network.driver
  }
}

output "volumes_info" {
  description = "Information about created Docker volumes"
  value = {
    monitoring_data = {
      name = docker_volume.monitoring_data.name
      mountpoint = docker_volume.monitoring_data.mountpoint
    }
    shared_scripts = {
      name = docker_volume.shared_scripts.name
      mountpoint = docker_volume.shared_scripts.mountpoint
    }
  }
}

output "container_endpoints" {
  description = "Endpoints for accessing monitoring containers"
  value = {
    for i, container in docker_container.ubuntu_monitor :
    "instance-${i + 1}" => {
      ssh_command = "docker exec -it ${container.name} /bin/bash"
      ip_address = container.networks_advanced[0].ipv4_address
      container_name = container.name
    }
  }
}

output "monitoring_urls" {
  description = "URLs for accessing monitoring services"
  value = {
    kibana = "http://localhost:5601"
    elasticsearch = "http://localhost:9200"
    logstash_api = "http://localhost:9600"
    semaphore_ui = "http://localhost:3000"
  }
}

output "resource_summary" {
  description = "Summary of created resources"
  value = {
    containers_created = length(docker_container.ubuntu_monitor)
    networks_created = 1
    volumes_created = 2
    total_memory_allocated = "${var.container_memory_limit * length(docker_container.ubuntu_monitor)}MB"
    project_name = var.project_name
    environment = var.environment
  }
}

output "next_steps" {
  description = "Next steps for configuration"
  value = {
    ansible_inventory_update = "Update semaphore/ansible/inventory/hosts.yml with the IP addresses above"
    semaphore_configuration = "Configure Semaphore UI at http://localhost:3000"
    monitoring_setup = "Run Ansible playbooks to configure monitoring on the created instances"
    dashboard_access = "Access Kibana dashboards at http://localhost:5601"
  }
}
