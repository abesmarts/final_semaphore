#!/bin/bash
set -e

# Kibana Dashboard Creation Script
echo "📊 Creating Kibana Dashboards for Infrastructure Monitoring..."

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

# Configuration
KIBANA_URL="http://localhost:5601"
DASHBOARD_FILE="kibana/dashboards/system-monitoring.json"
MAX_RETRIES=30
RETRY_INTERVAL=10

# Function to check if Kibana is ready
check_kibana_ready() {
    local retry_count=0
    
    print_status "Waiting for Kibana to be ready..."
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if curl -s -f "${KIBANA_URL}/api/status" > /dev/null 2>&1; then
            print_success "Kibana is ready!"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        print_status "Attempt $retry_count/$MAX_RETRIES - Kibana not ready yet, waiting ${RETRY_INTERVAL}s..."
        sleep $RETRY_INTERVAL
    done
    
    print_error "Kibana failed to become ready after $((MAX_RETRIES * RETRY_INTERVAL)) seconds"
    return 1
}

# Function to create index patterns
create_index_patterns() {
    print_status "Creating index patterns..."
    
    # Create monitoring index pattern
    curl -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/monitoring-pattern" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "title": "monitoring-*",
                "timeFieldName": "@timestamp",
                "fields": "[{\"name\":\"@timestamp\",\"type\":\"date\",\"searchable\":true,\"aggregatable\":true}]"
            }
        }' > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Created monitoring-* index pattern"
    else
        print_warning "Monitoring index pattern may already exist"
    fi
    
    # Create system monitoring index pattern  
    curl -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/system-monitoring-pattern" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "title": "system-monitoring-*", 
                "timeFieldName": "@timestamp",
                "fields": "[{\"name\":\"@timestamp\",\"type\":\"date\",\"searchable\":true,\"aggregatable\":true}]"
            }
        }' > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        print_success "Created system-monitoring-* index pattern"
    else
        print_warning "System monitoring index pattern may already exist"
    fi
    
    # Create web automation index pattern
    curl -X POST "${KIBANA_URL}/api/saved_objects/index-pattern/web-automation-pattern" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "title": "web-automation-*",
                "timeFieldName": "@timestamp", 
                "fields": "[{\"name\":\"@timestamp\",\"type\":\"date\",\"searchable\":true,\"aggregatable\":true}]"
            }
        }' > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        print_success "Created web-automation-* index pattern"
    else
        print_warning "Web automation index pattern may already exist"  
    fi
}

# Function to import dashboard
import_dashboard() {
    print_status "Importing system monitoring dashboard..."
    
    if [ ! -f "$DASHBOARD_FILE" ]; then
        print_error "Dashboard file not found: $DASHBOARD_FILE"
        return 1
    fi
    
    # Import the dashboard
    curl -X POST "${KIBANA_URL}/api/saved_objects/_import" \
        -H "kbn-xsrf: true" \
        -H "Content-Type: application/json" \
        --form file=@"$DASHBOARD_FILE" > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        print_success "Dashboard imported successfully"
    else
        print_warning "Dashboard import may have failed or dashboard already exists"
    fi
}

# Function to create sample visualizations
create_sample_visualizations() {
    print_status "Creating sample visualizations..."
    
    # CPU Usage Line Chart
    curl -X POST "${KIBANA_URL}/api/saved_objects/visualization/cpu-usage-chart" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "title": "CPU Usage Over Time",
                "visState": "{\"title\":\"CPU Usage Over Time\",\"type\":\"line\",\"params\":{\"grid\":{\"categoryLines\":false,\"style\":{\"color\":\"#eee\"}},\"categoryAxes\":[{\"id\":\"CategoryAxis-1\",\"type\":\"category\",\"position\":\"bottom\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\"},\"labels\":{\"show\":true,\"truncate\":100},\"title\":{}}],\"valueAxes\":[{\"id\":\"ValueAxis-1\",\"name\":\"LeftAxis-1\",\"type\":\"value\",\"position\":\"left\",\"show\":true,\"style\":{},\"scale\":{\"type\":\"linear\",\"mode\":\"normal\"},\"labels\":{\"show\":true,\"rotate\":0,\"filter\":false,\"truncate\":100},\"title\":{\"text\":\"CPU Usage (%)\"}}],\"seriesParams\":[{\"show\":true,\"type\":\"line\",\"mode\":\"normal\",\"data\":{\"label\":\"Average CPU Usage\",\"id\":\"1\"},\"valueAxis\":\"ValueAxis-1\",\"drawLinesBetweenPoints\":true,\"showCircles\":true}],\"addTooltip\":true,\"addLegend\":true,\"legendPosition\":\"right\",\"times\":[],\"addTimeMarker\":false},\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"avg\",\"schema\":\"metric\",\"params\":{\"field\":\"cpu.percent\"}},{\"id\":\"2\",\"enabled\":true,\"type\":\"date_histogram\",\"schema\":\"segment\",\"params\":{\"field\":\"@timestamp\",\"interval\":\"auto\",\"customInterval\":\"2h\",\"min_doc_count\":1,\"extended_bounds\":{}}}]}",
                "uiStateJSON": "{}",
                "kibanaSavedObjectMeta": {
                    "searchSourceJSON": "{\"index\":\"monitoring-*\",\"query\":{\"match\":{\"data_type\":\"system_monitoring\"}},\"filter\":[]}"
                }
            }
        }' > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Created CPU usage visualization"
    else
        print_warning "CPU usage visualization may already exist"
    fi
    
    # Memory Usage Gauge
    curl -X POST "${KIBANA_URL}/api/saved_objects/visualization/memory-gauge" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "title": "Current Memory Usage",
                "visState": "{\"title\":\"Current Memory Usage\",\"type\":\"gauge\",\"params\":{\"addTooltip\":true,\"addLegend\":false,\"isDisplayWarning\":false,\"type\":\"gauge\",\"gauge\":{\"alignment\":\"automatic\",\"extendRange\":true,\"colorSchema\":\"Green to Red\",\"colorsRange\":[{\"from\":0,\"to\":50},{\"from\":50,\"to\":80},{\"from\":80,\"to\":100}],\"invertColors\":false,\"labels\":{\"show\":true,\"color\":\"black\"},\"scale\":{\"show\":true,\"labels\":false,\"color\":\"#333\"},\"type\":\"meter\",\"style\":{\"bgFill\":\"#eee\",\"bgColor\":false,\"labelColor\":false,\"subText\":\"\",\"fontSize\":60}}},\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"avg\",\"schema\":\"metric\",\"params\":{\"field\":\"memory.percent\",\"customLabel\":\"Memory Usage (%)\"}}]}",
                "uiStateJSON": "{}",
                "kibanaSavedObjectMeta": {
                    "searchSourceJSON": "{\"index\":\"monitoring-*\",\"query\":{\"match\":{\"data_type\":\"system_monitoring\"}},\"filter\":[]}"
                }
            }
        }' > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        print_success "Created memory gauge visualization"
    else
        print_warning "Memory gauge visualization may already exist"
    fi
    
    # Web Automation Success Rate
    curl -X POST "${KIBANA_URL}/api/saved_objects/visualization/web-success-rate" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "title": "Web Login Success Rate",
                "visState": "{\"title\":\"Web Login Success Rate\",\"type\":\"metric\",\"params\":{\"addTooltip\":true,\"addLegend\":false,\"type\":\"metric\",\"metric\":{\"percentageMode\":true,\"useRanges\":false,\"colorSchema\":\"Green to Red\",\"metricColorMode\":\"Labels\",\"colorsRange\":[{\"from\":0,\"to\":80},{\"from\":80,\"to\":95},{\"from\":95,\"to\":100}],\"labels\":{\"show\":true},\"invertColors\":false,\"style\":{\"bgFill\":\"#000\",\"bgColor\":false,\"labelColor\":false,\"subText\":\"\",\"fontSize\":\"62\"}}},\"aggs\":[{\"id\":\"1\",\"enabled\":true,\"type\":\"avg\",\"schema\":\"metric\",\"params\":{\"field\":\"login_successful\",\"customLabel\":\"Success Rate\"}}]}",
                "uiStateJSON": "{}",
                "kibanaSavedObjectMeta": {
                    "searchSourceJSON": "{\"index\":\"monitoring-*\",\"query\":{\"match\":{\"data_type\":\"web_automation\"}},\"filter\":[]}"
                }
            }
        }' > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        print_success "Created web success rate visualization"
    else
        print_warning "Web success rate visualization may already exist"
    fi
}

# Function to set default index pattern
set_default_index_pattern() {
    print_status "Setting default index pattern..."
    
    curl -X POST "${KIBANA_URL}/api/saved_objects/config/9.0.4" \
        -H "Content-Type: application/json" \
        -H "kbn-xsrf: true" \
        -d '{
            "attributes": {
                "defaultIndex": "monitoring-pattern"
            }
        }' > /dev/null 2>&1
        
    if [ $? -eq 0 ]; then
        print_success "Set default index pattern"
    else
        print_warning "Default index pattern may already be set"
    fi
}

# Function to create sample data
create_sample_data() {
    print_status "Creating sample monitoring data..."
    
    # Send sample system monitoring data
    curl -X POST "http://localhost:5000" \
        -H "Content-Type: application/json" \
        -d '{
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
            "hostname": "sample-host",
            "data_type": "system_monitoring",
            "cpu": {"percent": 45.2, "count": 8},
            "memory": {"percent": 67.5, "total_bytes": 17179869184},
            "disk": {"percent": 23.8, "total_bytes": 1073741824000},
            "environment": "development",
            "project": "infrastructure-monitoring"
        }' > /dev/null 2>&1
        
    # Send sample web automation data
    curl -X POST "http://localhost:5000" \
        -H "Content-Type: application/json" \
        -d '{
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'",
            "data_type": "web_automation", 
            "website_url": "https://example.com/login",
            "login_successful": true,
            "response_time_seconds": 2.3,
            "environment": "development",
            "project": "infrastructure-monitoring"
        }' > /dev/null 2>&1
        
    print_success "Sample data created"
}

# Main execution
main() {
    print_status "Starting Kibana dashboard creation process..."
    
    # Check if Kibana is ready
    if ! check_kibana_ready; then
        print_error "Cannot proceed - Kibana is not ready"
        exit 1
    fi
    
    # Wait a bit more for Kibana to fully initialize
    print_status "Waiting for Kibana to fully initialize..."
    sleep 10
    
    # Create index patterns
    create_index_patterns
    
    # Set default index pattern
    set_default_index_pattern
    
    # Create sample visualizations
    create_sample_visualizations
    
    # Import dashboard if file exists
    if [ -f "$DASHBOARD_FILE" ]; then
        import_dashboard
    else
        print_warning "Dashboard file not found, skipping dashboard import"
    fi
    
    # Create some sample data
    create_sample_data
    
    # Wait for data to be indexed
    print_status "Waiting for data to be indexed..."
    sleep 5
    
    echo ""
    echo "Dashboard Creation Summary:"
    echo "=============================="
    echo "Index patterns created"
    echo "Sample visualizations created"
    echo "Sample data generated"
    echo ""
    echo "Access your dashboards at:"
    echo "   Kibana: ${KIBANA_URL}"
    echo "   Discover: ${KIBANA_URL}/app/discover"
    echo "   Visualizations: ${KIBANA_URL}/app/visualize"
    echo "   Dashboards: ${KIBANA_URL}/app/dashboards"
    echo ""
    
    print_success "Kibana dashboard creation completed! 🎉"
}

# Run main function
main "$@"
