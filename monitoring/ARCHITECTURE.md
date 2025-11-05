# Monitoring Stack - Architecture

## Stack Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Monitoring Infrastructure                    │
└─────────────────────────────────────────────────────────────────┘

┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Grafana    │◄─────┤  Prometheus  │◄─────┤   Targets    │
│   :3001      │      │    :9090     │      │              │
└──────────────┘      └──────────────┘      └──────────────┘
                                                    │
                    ┌───────────────────────────────┼───────────────────────────┐
                    │                               │                           │
            ┌───────▼──────┐              ┌────────▼────────┐        ┌─────────▼────────┐
            │ Node Exporter│              │ MySQL Exporter  │        │  Application     │
            │    :9100     │              │     :9104       │        │    Metrics       │
            └──────────────┘              └─────────────────┘        └──────────────────┘
                    │                               │                         │
            ┌───────▼──────┐              ┌────────▼────────┐        ┌───────▼──────────┐
            │ System Stats │              │   MySQL DB      │        │  Laravel App     │
            │ CPU, Memory  │              │     :3306       │        │  WhatsApp Client │
            │ Disk, Network│              └─────────────────┘        └──────────────────┘
            └──────────────┘
```

## Services Architecture

### 1. **Prometheus** (Port 9090)
- **Role**: Metrics collector & time-series database
- **Scrape Interval**: 15 seconds
- **Data Retention**: 30 days
- **Targets**:
  - Self monitoring
  - Node Exporter
  - MySQL Exporter
  - Laravel Application
  - WhatsApp Client

### 2. **Grafana** (Port 3001)
- **Role**: Metrics visualization & dashboards
- **Data Source**: Prometheus (auto-configured)
- **Default Credentials**: admin/admin123
- **Pre-installed Plugins**:
  - Clock Panel
  - Simple JSON Datasource
  - Piechart Panel

### 3. **Node Exporter** (Port 9100)
- **Role**: System metrics exporter
- **Metrics**:
  - CPU usage & load
  - Memory usage
  - Disk I/O & space
  - Network traffic
  - System info

### 4. **MySQL Exporter** (Port 9104)
- **Role**: MySQL database metrics exporter
- **Metrics**:
  - Connection count
  - Query performance
  - InnoDB status
  - Table statistics
  - Replication lag

## Data Flow

```
Application/System
       │
       │ expose metrics
       ▼
  /metrics endpoint
       │
       │ scrape (every 15s)
       ▼
   Prometheus
       │
       │ store time-series data
       ▼
  Prometheus TSDB
       │
       │ query (PromQL)
       ▼
    Grafana
       │
       │ render dashboards
       ▼
     User
```

## Network Architecture

All services run in the same Docker network (`app_network`):

```
┌─────────────────────────────────────────────────────────────┐
│                     app_network (bridge)                     │
│                                                              │
│  ┌────────┐  ┌────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  app   │  │   db   │  │  caddy   │  │  whatsapp    │   │
│  │        │  │        │  │          │  │   client     │   │
│  └────────┘  └────────┘  └──────────┘  └──────────────┘   │
│                                                              │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────┐    │
│  │  prometheus  │  │    grafana    │  │ node-exporter│    │
│  └──────────────┘  └───────────────┘  └──────────────┘    │
│                                                              │
│  ┌───────────────┐                                          │
│  │mysql-exporter │                                          │
│  └───────────────┘                                          │
└─────────────────────────────────────────────────────────────┘
```

## Port Mapping

| Service         | Internal Port | External Port | Protocol |
|-----------------|---------------|---------------|----------|
| Laravel App     | 9000          | -             | FastCGI  |
| MySQL           | 3306          | 3306          | TCP      |
| Caddy           | 80, 443       | 80, 443       | HTTP/S   |
| WhatsApp Client | 5555          | 5555          | HTTP     |
| Prometheus      | 9090          | 9090          | HTTP     |
| Grafana         | 3000          | 3001          | HTTP     |
| Node Exporter   | 9100          | 9100          | HTTP     |
| MySQL Exporter  | 9104          | 9104          | HTTP     |

## Metrics Collection Strategy

### 1. Pull-based (Prometheus scraping)
```
Prometheus → scrapes → /metrics endpoint
```

### 2. Push-based (for jobs/batches)
```
Application → pushes → Pushgateway → Prometheus
```
(Not implemented yet, can be added if needed)

## Storage & Volumes

```
┌──────────────────────────────────────────────────────────┐
│                    Persistent Volumes                     │
├──────────────────────────────────────────────────────────┤
│                                                           │
│  prometheus_data/      → Prometheus TSDB                 │
│  grafana_data/         → Grafana dashboards & settings   │
│  db_api/               → MySQL database                  │
│  whatsapp-session/     → WhatsApp sessions               │
│  caddy_data/           → Caddy certificates              │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

## Configuration Files

```
skincare/
├── monitoring/
│   ├── prometheus.yml         # Prometheus main config
│   ├── alerts.yml             # Alert rules
│   ├── grafana-datasources.yml # Grafana datasources
│   └── grafana-dashboards.yml  # Dashboard provisioning
├── compose.yaml               # Docker services
└── Makefile                   # Helper commands
```

## Alert Flow (Future Enhancement)

```
Metric threshold exceeded
        │
        ▼
Prometheus evaluates rule
        │
        ▼
Alert triggered
        │
        ▼
Alertmanager (not yet configured)
        │
        ├─► Email notification
        ├─► Slack notification
        ├─► PagerDuty
        └─► Webhook
```

## Security Considerations

### Current Setup (Development)
- ✅ Isolated Docker network
- ✅ No external database access
- ⚠️ Default Grafana password
- ⚠️ Open Prometheus endpoint
- ⚠️ No authentication on metrics

### Production Recommendations
- 🔒 Change all default passwords
- 🔒 Enable Prometheus authentication
- 🔒 Use reverse proxy with SSL
- 🔒 Restrict port access (firewall)
- 🔒 Use secrets management
- 🔒 Enable Grafana OAuth
- 🔒 Set up Alertmanager with encryption

## Scaling Strategy

### Horizontal Scaling
```
Load Balancer
     │
     ├─► App Instance 1 ──┐
     ├─► App Instance 2 ──┼─► Prometheus Federation
     └─► App Instance 3 ──┘
```

### Metrics Aggregation
- Use Prometheus federation for multiple instances
- Configure separate Prometheus per datacenter
- Aggregate in central Grafana

## Quick Commands

```bash
# Start all services
make up

# View monitoring info
make monitoring

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq

# Test Laravel metrics
curl http://localhost/metrics

# Test WhatsApp metrics
curl http://localhost:5555/metrics

# Check Grafana health
curl http://localhost:3001/api/health
```

## Troubleshooting Guide

### Prometheus not scraping
1. Check targets: http://localhost:9090/targets
2. Verify network connectivity: `docker network inspect skincare_app_network`
3. Check logs: `make logs-prometheus`

### Grafana not showing data
1. Verify datasource: Settings → Data Sources → Prometheus
2. Test query in Explore tab
3. Check time range selection

### High resource usage
1. Reduce scrape interval in `prometheus.yml`
2. Decrease retention period
3. Add resource limits in `compose.yaml`

## Resources & Links

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Tutorials](https://grafana.com/tutorials/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
- [MySQL Exporter Guide](https://github.com/prometheus/mysqld_exporter)
