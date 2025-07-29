#!/bin/bash
set -e

# Service startup script for Infrastructure Monitoring Project (VM-based Architecture)
echo "Starting Infrastructure Monitoring Services..."

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

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

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Stop any existing services
print_status "Stopping any existing services..."
docker compose down > /dev/null 2>&1 || true

# Start infrastructure services
print_status "Starting infrastructure monitoring services..."
print_status "Services starting: Elasticsearch, Kibana, Filebeat, Semaphore UI"
docker compose up -d

# Wait for services to initialize
print_status "Waiting for services to start up..."
sleep 45

# Function to check service health with retries
check_service() {
    local service_name=$1
    local url=$2
    local max_retries=10
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            print_success "$service_name is healthy"
            return 0
        fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            print_status "$service_name not ready yet, retrying ($retry_count/$max_retries)..."
            sleep 10
        fi
    done
    
    print_warning "$service_name may not be ready yet (max retries reached)"
    return 1
}

# Check service health
print_status "Checking service health..."

# Check Elasticsearch
check_service "Elasticsearch" "http://localhost:9200/_cluster/health"

# Check Kibana  
check_service "Kibana" "http://localhost:5601/api/status"

# Check Logstash
check_service "Logstash" "http://localhost:9600"

# Check Semaphore UI
check_service "Semaphore UI" "http://localhost:3000"

# Verify Docker network
print_status "Verifying Docker network..."
if docker network ls | grep -q "monitoring-network"; then
    print_success "Monitoring network is active"
else
    print_warning "Monitoring network may not be available"
fi

# Check container status
print_status "Checking container status..."
RUNNING_CONTAINERS=$(docker compose ps --format "table {{.Service}}\t{{.Status}}" | grep -c "Up" || echo "0")
EXPECTED_CONTAINERS=4  # elasticsearch, kibana, filebeat, semaphore

if [ "$RUNNING_CONTAINERS" -eq "$EXPECTED_CONTAINERS" ]; then
    print_success "All $EXPECTED_CONTAINERS containers are running"
else
    print_warning "Only $RUNNING_CONTAINERS out of $EXPECTED_CONTAINERS containers are running"
    echo ""
    print_status "Container status details:"
    docker compose ps
fi

# Test Filebeat data ingestion
print_status "Testing Filebeat data ingestion..."
TEST_DATA='{
    "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
    "message": "Service startup test",
    "service": "infrastructure-monitoring",
    "test": true
}'

if curl -s -X POST -H "Content-Type: application/json" -d "$TEST_DATA" http://localhost:5000 > /dev/null; then
    print_success "Filebeat HTTP input is accepting data"
else
    print_warning "Filebeat HTTP input may not be ready"
fi

# Check if Elasticsearch is indexing data
print_status "Verifying Elasticsearch data indexing..."
sleep 5
INDEX_COUNT=$(curl -s "http://localhost:9200/_cat/indices?format=json" 2>/dev/null | jq length 2>/dev/null || echo "0")
if [ "$INDEX_COUNT" -gt 0 ]; then
    print_success "Elasticsearch has created $INDEX_COUNT indices"
else
    print_status "No indices created yet (this is normal on first startup)"
fi

# Display service URLs and next steps
echo ""
echo "Service Access URLs:"
echo "==================="
echo "Semaphore UI:  http://localhost:3000"
echo "    - Username: admin"
echo "    - Password: SecurePassword123!"
echo "    - Use this to manage VM provisioning and automation"
echo ""
echo "Kibana:        http://localhost:5601"
echo "    - Data visualization and dashboards"
echo "    - No authentication required"
echo ""
echo "Elasticsearch: http://localhost:9200"
echo "    - Raw data storage and search API"
echo "    - Health: http://localhost:9200/_cluster/health"
echo ""
echo "Filebeat:      http://localhost:5066/stats"
echo "    - Lightweight log shipper statistics"
echo "    - Data ingestion endpoint: http://localhost:5000"
echo ""
echo "Next Steps for Complete Setup:"
echo "============================="
echo "1. Configure Semaphore UI:"
echo "   • Log in at http://localhost:3000"
echo "   • Create new project: 'Infrastructure Monitoring'"
echo "   • Add SSH keys for VM access"
echo "   • Configure Git repository integration"
echo ""
echo "2. Set up Infrastructure Automation:"
echo "   • Create Task Template for VM provisioning (Terraform)"
echo "   • Create Task Template for Ubuntu setup (Ansible)"
echo "   • Create Task Template for Chrome installation (Ansible)"
echo "   • Create Task Template for Python script deployment (Ansible)"
echo ""
echo "3. Provision and Configure VMs:"
echo "   • Run VM provisioning task in Semaphore"
echo "   • Configure Ubuntu systems with monitoring tools"
echo "   • Deploy Python scripts to VMs (not containers!)"
echo "   • Start monitoring services on VMs"
echo ""
echo "4. Verify Data Flow:"
echo "   • Check Kibana for incoming monitoring data"
echo "   • Create dashboards for system metrics"
echo "   • Set up alerting for critical thresholds"
echo ""
echo "Important Architecture Notes:"
echo "============================"
echo "• Python scripts run INSIDE VMs, not in Docker containers"
echo "• Ansible manages Python environments within each VM"
echo "• Semaphore orchestrates the entire VM lifecycle"
echo "• Filebeat replaced Logstash for lightweight log shipping"
echo "• All configuration values are hardcoded (no .env file needed)"
echo "• Use Semaphore UI for all infrastructure management"
echo ""

# Check for common issues
print_status "Checking for common setup issues..."

# Check available memory
MEMORY_USAGE=$(docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}" 2>/dev/null || echo "Cannot check memory")
if [[ "$MEMORY_USAGE" != "Cannot check memory" ]]; then
    print_status "Current Docker memory usage:"
    echo "$MEMORY_USAGE"
fi

# Check available disk space
AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ ${AVAILABLE_SPACE%.*} -lt 5 ]]; then
    print_warning "Low disk space: ${AVAILABLE_SPACE}GB available"
fi

# Final status
echo ""
if [ "$RUNNING_CONTAINERS" -eq "$EXPECTED_CONTAINERS" ]; then
    print_success "Infrastructure services started successfully!"
    print_status "Ready for VM provisioning through Semaphore UI"
else
    print_warning "Some services may need additional time to start"
    print_status "Check individual container logs: docker compose logs [service-name]"
fi

echo ""
print_status "Allow 2-3 minutes for full service initialization before using Semaphore UI"
