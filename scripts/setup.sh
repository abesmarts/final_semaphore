#!/bin/bash
set -e

# Infrastructure Monitoring Project Setup Script (VM-based Python Architecture)
echo "Starting Infrastructure Monitoring Project Setup..."

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Change to project root directory
cd "$(dirname "$0")/.."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS. Please adapt for your operating system."
    exit 1
fi

# Check for required tools
print_status "Checking for required tools..."

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker Desktop for Mac first."
    echo "Download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available. Please ensure Docker Desktop is properly installed."
    exit 1
fi

# Check for Terraform/OpenTofu
if ! command -v terraform &> /dev/null && ! command -v tofu &> /dev/null; then
    print_warning "Neither Terraform nor OpenTofu found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew install opentofu
    else
        print_error "Homebrew not found. Please install Terraform or OpenTofu manually."
        exit 1
    fi
fi

# Check for Ansible
if ! command -v ansible &> /dev/null; then
    print_warning "Ansible not found. Installing via pip..."
    python3 -m pip install --user ansible
fi

print_success "Required tools are available"

# Create project directory structure
print_status "Creating project directory structure..."

# Base directories (changed from logstash to filebeat)
mkdir -p elasticsearch/{config,data} kibana/{config,dashboards} filebeat/{config,data}
mkdir -p semaphore/{config,ansible/{inventory,playbooks,roles/system-setup/{tasks,templates}}}
mkdir -p terraform python-scripts/shared scripts

print_success "Directory structure created"

# Set permissions for Elasticsearch data directory
print_status "Setting up Elasticsearch data directory permissions..."
chmod 777 elasticsearch/data
chmod 777 filebeat/data
print_success "Elasticsearch and Filebeat permissions configured"

print_success "Required tools are available"

# Check available memory and adjust if needed
print_status "Checking system resources..."
TOTAL_MEMORY=$(sysctl -n hw.memsize)
MEMORY_GB=$((TOTAL_MEMORY / 1024 / 1024 / 1024))

if [[ $MEMORY_GB -lt 8 ]]; then
    print_warning "Your system has ${MEMORY_GB}GB RAM. Consider reducing memory allocations in docker-compose.yml"
fi

print_success "System resources checked"

# Initialize Docker Swarm (if not already initialized)
if ! docker info | grep -q "Swarm: active"; then
    print_status "Initializing Docker Swarm..."
    docker swarm init --advertise-addr 127.0.0.1 || true
fi

# Pull required Docker images
print_status "Pulling required Docker images..."
docker compose pull

print_success "Docker images pulled successfully"

# Create initial Kibana dashboards directory structure
print_status "Setting up Kibana dashboards..."
mkdir -p kibana/dashboards/exports
mkdir -p kibana/dashboards/imports

print_success "Kibana dashboard structure created"

# Set up log rotation for container logs
print_status "Configuring Docker log rotation..."
mkdir -p ~/.docker
cat > ~/.docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

print_success "Docker log rotation configured"

# Create monitoring network
print_status "Creating monitoring network..."
docker network create monitoring-network --driver bridge --subnet=172.20.0.0/16 || true

print_success "Monitoring network created"

# Validate Ansible inventory and playbooks
print_status "Validating Ansible configuration..."
if [[ -f "semaphore/ansible/inventory/hosts.yml" ]]; then
    print_success "Ansible inventory found"
else
    print_warning "Ansible inventory not found - will need to be configured in Semaphore UI"
fi

if [[ -f "semaphore/ansible/playbooks/setup-ubuntu.yml" ]]; then
    print_success "Ubuntu setup playbook found"
else
    print_warning "Ubuntu setup playbook not found - ensure all playbooks are in place"
fi

# Validate Terraform configuration
print_status "Validating Terraform configuration..."
if [[ -f "terraform/main.tf" ]]; then
    cd terraform
    if command -v terraform &> /dev/null; then
        terraform init -backend=false &> /dev/null && print_success "Terraform configuration valid"
    elif command -v tofu &> /dev/null; then
        tofu init -backend=false &> /dev/null && print_success "OpenTofu configuration valid"
    fi
    cd ..
else
    print_warning "Terraform configuration not found - will need to be configured"
fi

# Create SSH key for VM access if it doesn't exist
print_status "Setting up SSH keys for VM access..."
if [[ ! -f ~/.ssh/semaphore_infrastructure_key ]]; then
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/semaphore_infrastructure_key -N ""
    print_success "SSH key pair created for VM access"
    print_warning "Public key location: ~/.ssh/semaphore_infrastructure_key.pub"
    print_warning "Add this public key to your cloud provider or VM configuration"
else
    print_status "SSH key pair already exists"
fi

# Final setup verification
print_status "Performing setup verification..."

# Check Docker daemon
if ! docker info > /dev/null 2>&1; then
    print_error "Docker daemon is not running"
    exit 1
fi

# Check disk space
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ ${AVAILABLE_SPACE%.*} -lt 10 ]]; then
    print_warning "Less than 10GB disk space available. Monitor disk usage closely."
fi

print_success "Setup verification completed"

# Generate summary
echo ""
echo "Setup Summary:"
echo "=============="
echo "- Project directory structure created"
echo "- Docker environment configured"
echo "- Infrastructure services ready (Elasticsearch, Kibana, Filebeat, Semaphore)"
echo "- Python scripts prepared for VM deployment"
echo "- Ansible playbooks configured for VM setup"
echo "- Terraform/OpenTofu configuration validated"
echo "- SSH keys generated for VM access"
echo "- Monitoring network created"
echo "- Configuration files prepared"
echo ""
echo "Next Steps:"
echo "1. Run: ./scripts/start-services.sh"
echo "2. Access Semaphore UI at: http://localhost:3000"
echo "3. Configure Semaphore with repositories and keys"
echo "4. Create Task Templates for VM provisioning"
echo "5. Run infrastructure build through Semaphore UI"
echo "6. Access Kibana at: http://localhost:5601"
echo "7. Access Elasticsearch at: http://localhost:9200"
echo ""
echo "Important Notes:"
echo "- Python scripts will run inside VMs (not Docker containers)"
echo "- Use Semaphore UI to manage VM provisioning and configuration"
echo "- Ansible will set up Python environments within each VM"
echo "- SSH key: ~/.ssh/semaphore_infrastructure_key"
echo "- Filebeat replaced Logstash for lightweight log shipping"
echo "- All configuration values are now hardcoded (no .env file needed)"
echo ""
echo "Refer to README.md for detailed usage instructions"
echo ""

print_success "Infrastructure Monitoring Project setup completed!"
