#!/bin/bash

set -e

echo "Verifying Monitoring Setup..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if containers are running
echo -e "\n${YELLOW}1. Checking containers...${NC}"
if sudo docker ps | grep -q "skincare_prometheus"; then
    echo -e "${GREEN}✓ Prometheus is running${NC}"
else
    echo -e "${RED}✗ Prometheus is not running${NC}"
    exit 1
fi

if sudo docker ps | grep -q "skincare_grafana"; then
    echo -e "${GREEN}✓ Grafana is running${NC}"
else
    echo -e "${RED}✗ Grafana is not running${NC}"
    exit 1
fi

if sudo docker ps | grep -q "skincare_node_exporter"; then
    echo -e "${GREEN}✓ Node Exporter is running${NC}"
else
    echo -e "${RED}✗ Node Exporter is not running${NC}"
    exit 1
fi

# Check Prometheus targets
echo -e "\n${YELLOW}2. Checking Prometheus targets...${NC}"
sleep 5 # Wait for Prometheus to be ready

TARGETS_UP=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"up"' | wc -l)
TARGETS_DOWN=$(curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"down"' | wc -l)

echo -e "${GREEN}✓ Targets UP: $TARGETS_UP${NC}"
if [ "$TARGETS_DOWN" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Targets DOWN: $TARGETS_DOWN${NC}"
    curl -s http://localhost:9090/api/v1/targets | grep -o '"job":"[^"]*","health":"down"' || true
fi

# Test Prometheus queries
echo -e "\n${YELLOW}3. Testing Prometheus queries...${NC}"

# Test CPU query
CPU_RESULT=$(curl -s 'http://localhost:9090/api/v1/query?query=100%20-%20(avg(irate(node_cpu_seconds_total%7Bmode%3D%22idle%22%7D%5B5m%5D))%20*%20100)' | grep -o '"status":"success"' | wc -l)
if [ "$CPU_RESULT" -eq 1 ]; then
    echo -e "${GREEN}✓ CPU query working${NC}"
else
    echo -e "${RED}✗ CPU query failed${NC}"
fi

# Test Memory query
MEM_RESULT=$(curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemAvailable_bytes' | grep -o '"status":"success"' | wc -l)
if [ "$MEM_RESULT" -eq 1 ]; then
    echo -e "${GREEN}✓ Memory query working${NC}"
else
    echo -e "${RED}✗ Memory query failed${NC}"
fi

# Check Grafana datasource
echo -e "\n${YELLOW}4. Checking Grafana datasource...${NC}"
sleep 10 # Wait for Grafana to be ready

DATASOURCE_CHECK=$(curl -s -u admin:admin123 'http://localhost:3002/api/datasources/uid/prometheus' | grep -o '"uid":"prometheus"' | wc -l)
if [ "$DATASOURCE_CHECK" -eq 1 ]; then
    echo -e "${GREEN}✓ Grafana datasource configured correctly${NC}"
else
    echo -e "${RED}✗ Grafana datasource not found or misconfigured${NC}"
    echo -e "${YELLOW}⚠ Restarting Grafana to reload provisioning...${NC}"
    sudo docker restart skincare_grafana
    sleep 15
fi

# Check if dashboard exists
echo -e "\n${YELLOW}5. Checking Grafana dashboards...${NC}"
DASHBOARD_COUNT=$(curl -s -u admin:admin123 'http://localhost:3002/api/search?type=dash-db' | grep -o '"uid":"system-overview"' | wc -l)
if [ "$DASHBOARD_COUNT" -ge 1 ]; then
    echo -e "${GREEN}✓ System Overview dashboard found${NC}"
else
    echo -e "${RED}✗ System Overview dashboard not found${NC}"
fi

# Verify dashboard datasource UIDs
echo -e "\n${YELLOW}6. Verifying dashboard configuration...${NC}"
WRONG_UID_COUNT=$(grep -c '"uid": "PBFA97CFB590B2093"' monitoring/dashboards/system-overview.json 2>/dev/null || echo 0)
if [ "$WRONG_UID_COUNT" -gt 0 ]; then
    echo -e "${RED}✗ Found $WRONG_UID_COUNT wrong datasource UIDs in dashboard${NC}"
    echo -e "${YELLOW}⚠ Fixing datasource UIDs...${NC}"
    sed -i 's/"uid": "PBFA97CFB590B2093"/"uid": "prometheus"/g' monitoring/dashboards/system-overview.json
    sudo docker restart skincare_grafana
    echo -e "${GREEN}✓ Fixed and restarted Grafana${NC}"
else
    echo -e "${GREEN}✓ Dashboard datasource UIDs are correct${NC}"
fi

# Final summary
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Monitoring setup verification complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "\nAccess Grafana at: ${YELLOW}http://localhost:3002${NC}"
echo -e "   Username: ${YELLOW}admin${NC}"
echo -e "   Password: ${YELLOW}admin123${NC}"
echo -e "\nAccess Prometheus at: ${YELLOW}http://localhost:9090${NC}"
echo -e "\n${YELLOW}Note: Wait 1-2 minutes for data to appear in dashboards${NC}\n"
