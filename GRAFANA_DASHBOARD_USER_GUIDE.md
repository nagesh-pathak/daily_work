# CDC Grafana Dashboards User Guide

## Overview
This guide provides a comprehensive overview of all Grafana dashboards used for monitoring CDC (Change Data Capture) services. The dashboards are organized into different categories for various monitoring purposes.

---

## 📁 Dashboard Categories

### 1. Production Final Dashboards (`production final/`)
These are the production-ready dashboards used for live monitoring.

#### 🔧 **CDC API Timeseries** (`CDCAPITimeseries.json`)
**Purpose**: Monitor CDC API service performance and health
**Data Included**:
- **API Request Metrics**: QPS (Queries Per Second) for different gRPC methods (GetFlow, ListFlows, CreateFlow, UpdateFlow, DeleteFlow)
- **System Metrics**: CPU and Memory usage per pod
- **Error Monitoring**: 4xx/5xx error rates, service errors
- **Alerts**: Service down alerts, requests unable to fulfill
- **Pod Management**: Pod restart monitoring

**Use Cases**:
- Track API performance and throughput
- Monitor service health and resource consumption
- Identify error patterns and service issues
- Alert on critical service failures

---

#### ⚡ **CDC Flow Timeseries** (`CDCFlowTimeseries.json`)
**Purpose**: Monitor CDC Flow service performance
**Data Included**:
- **API Request Metrics**: Similar to CDC API but for Flow service
- **System Metrics**: CPU and Memory usage for CDC Flow containers
- **Error Monitoring**: HTTP error rates and service errors
- **Alerts**: Service availability and performance alerts
- **Pod Management**: Flow service pod restarts

**Use Cases**:
- Monitor data flow processing performance
- Track flow service resource utilization
- Detect flow processing bottlenecks
- Alert on flow service disruptions

---

#### 📊 **CDC OnPrem Events Timeseries** (`CDCOnpremEventsTimeseries.json`)
**Purpose**: Monitor on-premises CDC event processing
**Data Included**:
- **Event Processing**: Accepted vs Drained Events Rate and Volume
- **Event Size Monitoring**: Processed and Pending Events Size
- **DNS Events**: DNS Cloud Events Rate, DNS Reporting Events Rate
- **RPZ Events**: RPZ Cloud Events Rate monitoring
- **IPMeta Events**: IPMeta Cloud Events Rate
- **Network Monitoring**: Open Sockets tracking

**Use Cases**:
- Monitor event ingestion and processing rates
- Track event queue sizes and processing delays
- Monitor different event types (DNS, RPZ, IPMeta)
- Identify network connectivity issues

---

#### 📈 **CDC OnPrem Flow Status Timeseries** (`CDCOnpremFlowStatusTimeseries.json`)
**Purpose**: Monitor the status and health of on-premises data flows
**Data Included**:
- **Flow Status Monitoring**: Current Flow Status tracking
- **Account Analytics**: Number of Flows by Account
- **Status Summary**: Flow Status Summary across all flows
- **Alerting**: CDC Flow Status Alerts

**Use Cases**:
- Track flow operational status
- Monitor flows per customer account
- Identify failed or problematic flows
- Generate flow status reports

---

#### 📋 **CDC OnPrem Logs Table** (`CDCOnpremLogsTable.json`)
**Purpose**: Analyze CDC service logs and error patterns
**Data Included**:
- **Error Log Analysis**: CDC Error Logs Summary
- **Error Rate Monitoring**: Top 50 Error Rate Increase
- **Account Information**: Customer account details
- **Log Exploration**: Direct Loki log exploration links

**Use Cases**:
- Investigate service errors and issues
- Track error rate trends
- Correlate errors with specific accounts
- Deep-dive into log details for troubleshooting

---

#### 🖥️ **CDC OnPrem Resources Table** (`CDCOnpremResourcesTable.json`)
**Purpose**: Monitor on-premises infrastructure resources
**Data Included**:
- **Service Summary**: CDC OnPrem Services Summary
- **Customer Overview**: CDC Customers Summary
- **Resource Alerts**: Memory, CPU, and Volume usage alerts (threshold-based)
- **Trend Analysis**: Top 20 hosts with increasing resource usage
- **Resource Tables**: Comprehensive resource usage tables

**Use Cases**:
- Monitor infrastructure health and capacity
- Identify resource-constrained hosts
- Plan capacity and scaling decisions
- Generate infrastructure reports

---

#### 📊 **CDC OnPrem Resources Timeseries** (`CDCOnpremResourcesTimeseries.json`)
**Purpose**: Time-series monitoring of on-premises resources
**Data Included**:
- **Memory Monitoring**: Memory usage exceeding thresholds
- **CPU Monitoring**: CPU usage exceeding thresholds  
- **Volume Monitoring**: Disk/Volume usage exceeding thresholds

**Use Cases**:
- Track resource usage trends over time
- Set up threshold-based monitoring
- Identify resource usage patterns

---

#### 🚨 **CDC OnPrem Resources Alerts** (`CDCOnpremResourcesAlerts.json`)
**Purpose**: Alert dashboard for resource threshold violations
**Data Included**:
- **Memory Alerts**: CDC OnPrem Memory Usage Alerts
- **CPU Alerts**: CDC OnPrem CPU Usage Alerts
- **Volume Alerts**: CDC OnPrem Volume Usage Alerts

**Use Cases**:
- Real-time alerting on resource issues
- Emergency response monitoring
- Infrastructure health status

---

#### 🏗️ **CDC OnPrem Pods Resources Timeseries** (`CDCOnpremPodsResourcesTimeseries.json`)
**Purpose**: Monitor Kubernetes pod-level resource consumption
**Data Included**:
- **CPU Metrics**: CDC Container CPU Usage %
- **Memory Metrics**: CDC Container Memory Usage %

**Use Cases**:
- Monitor containerized resource consumption
- Kubernetes cluster resource management
- Pod-level performance optimization

---

#### ☁️ **CDC Cloud to Cloud Timeseries** (`cloud2cloud.json`)
**Purpose**: Monitor cloud-to-cloud data transfer and processing
**Data Included**:
- **Resource Monitoring**: Memory & CPU Usage
- **Pod Management**: Pod Status & Restart monitoring
- **Kubernetes Resources**: ConfigMaps & StatefulSets
- **Network Monitoring**: Network Receive/Transmit Bytes
- **Alerting**: Pod failure, CPU, and Memory alerts

**Use Cases**:
- Monitor cloud data transfer performance
- Track cloud infrastructure health
- Manage Kubernetes resources
- Monitor network throughput

---

#### 📈 **EPS Log Types Dashboard** (`EPS_Log_types.json`)
**Purpose**: Monitor Events Per Second (EPS) by log type
**Data Included**:
- **EPS Overview**: Total EPS, Peak EPS, Active Log Types
- **Current Metrics**: Current EPS by Log Type and Data Type
- **Peak Analysis**: Peak EPS by Type over time
- **Time Series**: EPS trends by log type with interactive legends
- **Flow Analysis**: EPS by Source and Destination Flow
- **Idle Detection**: Low activity host detection (OPHID status)

**Use Cases**:
- Monitor event processing rates
- Analyze log type distribution
- Identify performance bottlenecks
- Detect idle or underutilized hosts
- Capacity planning for event processing

---

### 2. Development/Staging Dashboards (`eu-prod/`)
These are identical copies of production dashboards but configured for EU production environment.

### 3. SLI Dashboards (`sli/dashboards/`)
Service Level Indicator dashboards for measuring service performance against SLA targets.

### 4. Working Dashboards (`grafana/`)
Development and testing versions of dashboards.

#### 📊 **Flow Status Dashboards** (`grafana/flow status/`)
- **Flow Status Dashboard** (`flow-status.json`): Monitors CDC flow status by account and flow ID
- **Flow Status Alert** (`flow-status-alert.json`): Alert-specific flow status monitoring

#### 📋 **Table Dashboards** (`grafana/grafana table/`)
Various table-format dashboards showing:
- **table9Perfect.json**: Comprehensive CDC OnPrem Service Tables
- **table10Done.json**: Completed table configurations  
- Resource usage tables with different filtering and display options

#### 📈 **Timeseries Dashboards** (`grafana/grafana timeseries/`)
Time-series versions of various monitoring dashboards for trend analysis.

#### 🔧 **Backup Dashboards** (`grafana/backup/`)
- **cdc_unified_table.json**: Unified events table
- **EPS_Log_types.json**: Backup of EPS monitoring
- **CDCOnpremPodsResourcesTimeseries.json**: Backup pod monitoring

---

## 🎯 Dashboard Selection Guide

### For Operations Teams:
1. **Daily Monitoring**: Use Production Final dashboards
2. **Incident Response**: Start with CDC OnPrem Logs Table and Resources Alerts
3. **Performance Analysis**: Use Timeseries dashboards for trends

### For Development Teams:
1. **Service Development**: Use CDC API/Flow Timeseries dashboards
2. **Testing**: Use working dashboards in `grafana/` folder
3. **Integration**: Use SLI dashboards for service level monitoring

### For Infrastructure Teams:
1. **Capacity Planning**: Use Resources Table and Timeseries dashboards
2. **Health Monitoring**: Use Cloud to Cloud and Pods Resources dashboards
3. **Alert Management**: Use Resources Alerts dashboards

### For Business Teams:
1. **Customer Impact**: Use Flow Status dashboards
2. **Service Metrics**: Use EPS Log Types dashboard
3. **Account Analytics**: Use Flow Status and Resources Table dashboards

---

## 🔍 Key Metrics Explained

### **QPS (Queries Per Second)**
- Measures API request throughput
- Broken down by operation type (GetFlow, ListFlows, etc.)

### **EPS (Events Per Second)**
- Measures event processing throughput
- Critical for understanding data ingestion capacity

### **Flow Status**
- Indicates health of data flows
- Key for understanding service availability

### **Resource Usage**
- CPU, Memory, and Disk utilization
- Essential for capacity planning and performance optimization

### **Error Rates**
- 4xx: Client errors (bad requests)
- 5xx: Server errors (service issues)

---

## 🚨 Alert Priorities

### **Critical (P1)**
- Service Down alerts
- High error rates (>5%)
- Resource usage >90%

### **High (P2)**
- Flow failures
- Resource usage >70%
- Pod restarts

### **Medium (P3)**
- Performance degradation
- Resource usage >50%
- Log error increases

---

## 📞 Troubleshooting Quick Reference

### **Service Issues**
1. Check CDC API/Flow Timeseries for error rates
2. Review OnPrem Logs Table for specific errors
3. Examine Resources dashboards for capacity issues

### **Performance Issues**
1. Analyze EPS dashboard for throughput problems
2. Check Resources Timeseries for bottlenecks
3. Review Cloud to Cloud dashboard for network issues

### **Customer Impact**
1. Use Flow Status dashboard to identify affected flows
2. Check Flow Status by Account for customer-specific issues
3. Review Events Timeseries for data processing delays

---

*Last Updated: July 18, 2025*
*For support, refer to the SaaS Support Site linked in each dashboard*
