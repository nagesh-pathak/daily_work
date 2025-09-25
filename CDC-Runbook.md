# CDC Runbook (Support / Operations)

## 1. Purpose & Scope

This runbook provides operational guidance for monitoring, triaging, and resolving alerts generated from CDC OnPrem, Cloud, and Cloud-to-Cloud (C2C) components.

**Covers:**
- Event ingestion (OnPrem → Cloud)
- Flow service (cdc-flow namespace)
- API service (cdc-api namespace)
- Cloud-to-Cloud data pipeline (cdc-data-flow namespace)
- Resource and host health
- Pipeline freshness & lag
- Kubernetes pod health (all CDC namespaces)

**Out of scope:** Detailed deployment procedures, schema evolution, capacity planning (can be added later).

## 2. System Overview (High-Level)

**Components:**
- **OnPrem Collectors / Agents:** Ingest DNS/NIOS/BloxOne telemetry and forward to cloud
- **OnPrem Processing Containers:** Maintain sockets, compute EPS, persist buffer of pending events
- **CDC Cloud Ingestion (cdc-data-flow namespace):** Normalizes and routes events
- **Flow Service (cdc-flow namespace):** Exposes flow orchestration and business logic via gRPC & HTTP (through nginx ingress)
- **API Service (cdc-api namespace):** External API endpoints (gRPC + HTTP ingress)
- **Status Reporter & HostApp Sync:** Supporting services for flow/API state propagation
- **Prometheus (federated) + Grafana Dashboards:** Source of alert evaluations
- **PagerDuty / Notification Channels:** Escalation targets

## 3. Roles & Responsibilities

**L1 (NOC / 24x7 Ops):** Acknowledge, follow Immediate Actions, escalate if not resolved within timelines.

**L2 (Platform / SRE):** Deep diagnostics, remediation (scaling, restarts, config fix), root cause notes.

**L3 (Engineering):** Code-level issues, confirmed defects, architectural or data pipeline breakages.

**Escalation windows (suggested):**
- **Critical:** L1 → L2 within 10 min if unresolved; L2 → L3 within 30 min
- **Warning:** Review within 1 hour; escalate if persistent >2 consecutive alert evaluations
- **"N/A" severity:** Normalize (see Section 11 Recommendations)

## 4. Alert Taxonomy & Naming

**Pattern:** `[CDC][<Domain>] <Description> Alert`

**Domains:** OnPrem, Cloud, C2C

**Current attributes:**
- **Severity (Grafana tag)** – sometimes missing ("N/A")
- **Priority embedded in message** (Priority: High/Low) – inconsistent with Severity

**Recommendation:** Map Priority → Standard Severity (Critical / High / Medium / Low) and remove duplication.

## 5. Unified Triage Workflow

1. **Confirm Alert Context:** Open referenced dashboard by UID or title. Check time range (default last 1–3h).
2. **Correlate:** Look for companion alerts (e.g., Low EPS + No Events Received + Host Inactive).
3. **Gather Metrics:** Run PromQL queries (see per-alert section).
4. **Check Recent Changes:** Deployment? Config? Infrastructure incident?
5. **Execute Quick Remediation** (restart pod? scale? free disk?).
6. **Validate Recovery:** Metric returns to normal for >1 evaluation interval.
7. **Document:** Incident ticket: cause, actions, resolution time.
8. **Escalate:** If blocked or symptom repeats after remediation.

## 6. Alert Playbooks (Detailed)

### 6.1 OnPrem Comprehensive Alerts

#### 6.1.1 [CDC][OnPrem] Low EPS Alert

**Dashboard:** cdc-onprem-comprehensive-alert
**Condition:** Total EPS < 300 for 5m (avg over 10m window, evaluated every 5m)
**Impact:** Reduced telemetry ingestion → downstream analytics gaps.

**Likely Causes:**
- Source outage (NIOS/BloxOne side)
- Network disruption (firewall, VPN tunnel, bandwidth saturation)
- Socket churn or zero active flows
- Recent config change reducing filtering too aggressively

**Immediate Actions:**
- Confirm active flows (see "No Active Flows" alert)
- Check open sockets metric & pending backlog
- Validate source systems (NIOS/BloxOne) are reachable
- Inspect OnPrem logs for connection or auth errors
- If partial region-only drop: isolate endpoints (ophid)

**Validation:** EPS recovers > threshold for ≥2 evaluation cycles.
**Escalation:** L2 if persists >15m. L3 if correlated with code/log anomalies.

```promql
# PromQL - Low EPS
sum by (ophid) (rate(onprem_cdc_received_events_from_bloxone{ophid!="" , source="bloxone"}[1m]))
sum by (ophid) (rate(onprem_cdc_received_events_from_nios{ophid!=""}[1m]))
sum(rate(onprem_cdc_received_events_from_bloxone{ophid!="" , source="bloxone"}[1m])) 
  + sum(rate(onprem_cdc_received_events_from_nios{ophid!=""}[1m]))
```

#### 6.1.2 [CDC][OnPrem] Pending Event Backlog Alert

**Dashboard:** cdc-onprem-comprehensive-alert
**Condition:** Total pending events > 50,000 for 2m
**Impact:** Risk of eventual data loss if buffer overflows; processing latency.

**Likely Causes:** Downstream throttling, flow workers stalled, disk or CPU contention.

**Immediate Actions:**
- Check flow activity (Active Flows metric)
- Inspect resource alerts (CPU/Mem/Disk)
- Look for recent deployment or scaling events
- Check container logs for "backpressure" or queue errors
- If safe, scale processing workers (if supported)

**Validation:** Backlog trends downward over next 10–15m.
**Escalation:** L2 if growing > 15m; L3 if locked (flat high plateau + errors).

```promql
# PromQL - Pending Events
sum(onprem_cdc_pending_events{ophid!=""})
sum by (ophid) (onprem_cdc_pending_events{ophid!=""})
```

#### 6.1.3 [CDC][OnPrem] No Open Sockets Alert

**Dashboard:** cdc-onprem-comprehensive-alert
**Condition:** Sum of container sockets < 1 for 15m
**Impact:** No ingestion connectivity.

**Causes:** Network ACL change, DNS failure, certificate issue, container crash.

**Actions:**
- Correlate with Host Inactive / Pod restarts
- Check network route changes (VPN, security groups)
- Restart offending ingestion pods if isolated
- Validate DNS resolution inside container (exec test)

**Validation:** Socket count >0 and EPS recovers.
**Escalation:** Immediate L2 if lasts > one evaluation (already 15m window).

```promql
# PromQL - Open Sockets
sum(onprem_container_sockets{onprem_pod=~".*cdc.*", ophid!=""})
sum by (ophid) (onprem_container_sockets{onprem_pod=~".*cdc.*", ophid!=""})
```

#### 6.1.4 [CDC][OnPrem] No Active Flows Alert

**Dashboard:** cdc-onprem-comprehensive-alert
**Condition:** Active flows < 1 for 5m
**Impact:** Full ingestion / processing halt.

**Causes:** Flow scheduler failure, global config change, auth/secret rotation issue.

**Actions:**
- Verify flow status metrics & degraded flow alert
- Restart flow scheduler component if non-responsive
- Inspect recent configuration pushes (git/helm)
- Look for systemic Kubernetes node issues

**Validation:** Active flow count > 0.
**Escalation:** Immediate L2; L3 if recurring after restart.

```promql
# PromQL - Active Flows
count(cdc_flow_status == 1) or vector(0)
sum by (ophid) (cdc_flow_status{ophid!=""} == 1) 
  or on(ophid) (0 * group by (ophid) (cdc_flow_status{ophid!=""}))
```

#### 6.1.5 [CDC][C2C] High QPS Alert

**Dashboard:** cdc-onprem-comprehensive-alert
**Condition:** Total gRPC server started QPS > 100/s sustained 10m
**Impact:** Possible abuse, surge load, resource exhaustion risk.

**Causes:** Customer surge, looped client retries, test harness misconfig.

**Actions:**
- Break down by method (grpc_method label)
- Check 5xx / failure ratios (Flow/API downstream)
- Confirm autoscaling status
- Rate-limit abusive sources if identifiable

**Validation:** QPS stabilizes; no elevated error rates.
**Escalation:** L2 if accompanied by latency or errors.

```promql
# PromQL - High QPS
sum(irate(grpc_server_started_total{app=~"cdc.*"}[2m]))
sum by (grpc_method) (irate(grpc_server_started_total{app=~"cdc.*"}[2m]))
```

#### 6.1.6 [CDC][Cloud] No Events Received from Source Alert

**Dashboard:** cdc-onprem-comprehensive-alert
**Condition:** Combined event rates (bloxone + nios) near zero (<0.1) for 3m
**Impact:** Cloud ingestion gap; analytics blind spot.

**Causes:** OnPrem pipeline disruption, network egress blocked, auth revocation.

**Actions:**
- Cross-check Low EPS + OnPrem alerts (sockets, host status)
- Validate that sources still sending (look at last nonzero)
- Test network path (if tools available)
- Verify secrets / tokens not expired

**Validation:** Event rate resumes > baseline.
**Escalation:** Immediate L2 if persists > evaluation window.

```promql
# PromQL - Events Rate (Cloud side)
(sum(rate(onprem_cdc_received_events_from_bloxone{source="bloxone", ophid!=""}[1m])) 
 + sum(rate(onprem_cdc_received_events_from_nios{ophid!=""}[1m])))
```

### 6.2 OnPrem Flow Status Alerts

#### 6.2.1 [CDC][OnPrem] Flow Status Degraded Alert

**Dashboard:** cdc-onprem-flow-status-alerts
**Condition:** Any flows stuck Review >5m or Pending >3m
**Impact:** Latency & potential halting of activation pipelines.

**Causes:** Downstream dependency (DB, queue), validation deadlock, partial deployment mismatch.

**Actions:**
- Identify accounts with Review/Pending > thresholds
- Check application logs for validation or external API timeouts
- Confirm DB connectivity / latency
- Retry/retrigger stuck flow if supported

**Validation:** Counts decrement; states progress to Active.
**Escalation:** L2 if >15m; L3 if repeating pattern.

```promql
# PromQL - Flow States
count by (account_id) (cdc_flow_status == 0)     # Review
count by (account_id) (cdc_flow_status == 0.5)   # Pending
count by (account_id) (cdc_flow_status == 1)     # Active
```

### 6.3 OnPrem Resource Alerts

#### 6.3.1 [CDC][OnPrem] High Memory Usage Alert

**Dashboard:** cdc-onprem-resource-alerts
**Condition:** Memory >80% sustained for 1m
**Impact:** Risk of OOM kills + backlog.

**Causes:** Leaks, oversized buffers, JVM/Go heap growth due to spikes.

**Actions:**
- Identify top hosts (ophid)
- Check for recent version rollouts correlating with increase
- Restart offending process only if memory slope indicates leak
- Plan capacity increase if sustained normal load

**Validation:** Memory returns <70% sustained.
**Escalation:** L2 if >30m; L3 if repeating post-restart.

```promql
# PromQL - OnPrem Memory %
(
  onprem_host_memory_usage_used{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}
) / (
  onprem_host_memory_usage_total{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}
) * 100
```

#### 6.3.2 [CDC][OnPrem] High CPU Usage Alert

**Dashboard:** cdc-onprem-resource-alerts
**Condition:** CPU >80% sustained for 1m
**Impact:** Latency, processing slowdown.

**Causes:** Hot loops, increased event complexity, resource contention.

**Actions:**
- Compare with backlog / EPS metrics
- Identify processes consuming most CPU
- Check for runaway background tasks
- Consider scaling horizontally if load is legitimate

**Validation:** CPU usage returns <70% sustained.
**Escalation:** L2 if >20m; L3 if accompanied by errors.

```promql
# PromQL - OnPrem CPU %
(
  onprem_host_cpu_usage{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}
) * 100
```

#### 6.3.3 [CDC][OnPrem] High Disk Usage Alert

**Dashboard:** cdc-onprem-resource-alerts
**Condition:** Disk usage >50% sustained for 1m
**Impact:** Risk of outage due to full disk.

**Causes:** Log accumulation, data retention, failed cleanup jobs.

**Actions:**
- Identify largest files/directories
- Clean up old logs, temp files
- Check if data retention policies are working
- Expand storage if growth is expected

**Validation:** Disk usage drops <40%.
**Escalation:** L2 if >80% usage; L3 if cleanup doesn't help.

```promql
# PromQL - OnPrem Disk %
(
  onprem_host_disk_usage_used{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}
) / (
  onprem_host_disk_usage_total{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}
) * 100
```

### 6.4 OnPrem Host Status Alerts

#### 6.4.1 [CDC][OnPrem] Host Inactive Alert

**Dashboard:** cdc-onprem-host-status-alerts
**Condition:** Host service inactive for more than 5m
**Impact:** Complete loss of telemetry from affected host.

**Causes:** Network connectivity loss, host crash, service failure.

**Actions:**
- Check network connectivity to host
- Verify host system health and logs
- Restart CDC services if host is responsive
- Escalate to infrastructure team if host is unreachable

**Validation:** Host status returns to active.
**Escalation:** Immediate L2; L3 if multiple hosts affected.

```promql
# PromQL - Host Status
onprem_host_service_status{service=~"cdc.*"}
```

### 6.5 OnPrem Container Timestamp Alerts

#### 6.5.1 [CDC][OnPrem] Event Received/Delivered Timestamp Alert

**Dashboard:** cdc-onprem-container-timestamp-alerts
**Condition:** Event received/delivered timestamps unchanged for over 5m
**Impact:** Processing pipeline stall, data freshness issues.

**Causes:** Container freeze, processing deadlock, downstream bottleneck.

**Actions:**
- Verify event ingestion pipeline
- Check processing container health
- Inspect downstream delivery mechanisms
- Restart container if frozen

**Validation:** Timestamps resume updating.
**Escalation:** L2 if >10m; L3 if recurring.

#### 6.5.2 [CDC][OnPrem] Event Received/Delivered Timestamp Lag Alert

**Dashboard:** cdc-onprem-container-timestamp-alerts
**Condition:** Processing lag exceeded 5m
**Impact:** Data staleness, analytics delays.

**Causes:** Pipeline bottlenecks, resource constraints, downstream system health issues.

**Actions:**
- Investigate pipeline bottlenecks
- Check resource constraints (CPU, memory, disk)
- Verify downstream system health
- Scale processing if needed

**Validation:** Lag returns to <2m.
**Escalation:** L2 if lag >15m; L3 if persistent after scaling.

### 6.6 Cloud Flow Service Alerts

#### 6.6.1 [CDC][Cloud] Flow Dependent service(s) failure Alert

**Dashboard:** cdc-flow-alerts
**Condition:** CDC flow requests unable to fulfill (>5% failure rate over 1m)
**Impact:** Flow orchestration failures, service degradation.

**Causes:** Downstream dependency issues, database connectivity, external API failures.

**Actions:**
- Investigate impacted dependencies
- Check service health status
- Verify database connectivity
- Restore functionality through failover if available

**Validation:** Failure rate drops <1%.
**Escalation:** L2 immediately; L3 if dependency issue persists.

#### 6.6.2 [CDC][Cloud] Flow Service Down Alert

**Dashboard:** cdc-flow-alerts
**Condition:** CDC Flow service returning >5% 5xx errors over 5m
**Impact:** Possible outage, flow operations disrupted.

**Causes:** Service crash, resource exhaustion, infrastructure issues.

**Actions:**
- Investigate service health immediately
- Check upstream dependencies
- Review error logs
- Restart service if needed

**Validation:** 5xx error rate <1%.
**Escalation:** Immediate L2; critical priority.

#### 6.6.3 [CDC][Cloud] Flow Pod Restart Alert

**Dashboard:** cdc-flow-alerts
**Condition:** Flow pods restarting frequently
**Impact:** Service instability, potential data loss.

**Causes:** OOM kills, resource limits, node issues.

**Actions:**
- Monitor pod stability
- Check resource utilization
- Review pod logs
- Investigate underlying node health

**Validation:** Pod restarts cease.
**Escalation:** L2 if >3 restarts in 10m.

#### 6.6.4 [CDC][Cloud] Flow 4xx Error Alert

**Dashboard:** cdc-flow-alerts
**Condition:** Sustained 4xx client errors detected
**Impact:** Client integration issues, authentication problems.

**Causes:** Authentication failures, API route changes, malformed requests.

**Actions:**
- Check authentication mechanisms
- Verify API routes and versions
- Review request formats from clients
- Contact client teams if widespread

**Validation:** 4xx error rate normalizes.
**Escalation:** L2 if affecting multiple clients.

### 6.7 Cloud API Service Alerts

#### 6.7.1 [CDC][Cloud] API Requests Unable to Fulfill Alert

**Dashboard:** cdc-api-alerts
**Condition:** CDC API requests unable to fulfill (>5% failure rate over 1m)
**Impact:** API service degradation, client impact.

**Causes:** Downstream dependencies, database issues, service overload.

**Actions:**
- Investigate impacted dependencies
- Check service health
- Verify database connectivity
- Scale if needed

**Validation:** API success rate >95%.
**Escalation:** L2 immediately for business impact.

#### 6.7.2 [CDC][Cloud] API Service Down Alert

**Dashboard:** cdc-api-alerts
**Condition:** CDC API service returning >5% 5xx errors for 5m
**Impact:** Possible API outage.

**Causes:** Service crash, infrastructure failure, resource exhaustion.

**Actions:**
- Investigate service health immediately
- Check upstream dependencies
- Review error logs
- Restart if necessary

**Validation:** 5xx errors <1%.
**Escalation:** Immediate L2; critical.

#### 6.7.3 [CDC][Cloud] API Pod Restart Alert

**Dashboard:** cdc-api-alerts
**Condition:** CDC API pods are restarting
**Impact:** API instability.

**Causes:** Resource constraints, OOM, node issues.

**Actions:**
- Monitor pod stability
- Check resource usage
- Review logs
- Check node health

**Validation:** Restart frequency normalizes.
**Escalation:** L2 if persistent.

#### 6.7.4 [CDC][Cloud] API 4xx Error Alert

**Dashboard:** cdc-api-alerts
**Condition:** Sustained 4xx client errors detected
**Impact:** Client integration issues.

**Causes:** Authentication, routing, request format issues.

**Actions:**
- Check authentication
- Verify API routes
- Review request formats
- Client communication if needed

**Validation:** 4xx rate normalizes.
**Escalation:** L2 if widespread.

### 6.8 Cloud-to-Cloud (C2C) Data Flow Alerts

#### 6.8.1 [CDC][C2C] Pod Restart Alert

**Dashboard:** cdc-cloud-alerts
**Condition:** cdc-data-flow pod restarted in the last 5m
**Impact:** Data pipeline interruption.

**Causes:** Resource constraints, application errors, node issues.

**Actions:**
- Investigate restart frequency
- Check pod logs
- Review resource limits
- Verify node health

**Validation:** Restart events cease.
**Escalation:** L2 if frequent restarts.

#### 6.8.2 [CDC][C2C] Pod Failed Alert

**Dashboard:** cdc-cloud-alerts
**Condition:** cdc-data-flow pod is in Failed state
**Impact:** Complete data pipeline failure.

**Causes:** Crash loops, scheduling issues, resource constraints.

**Actions:**
- Check crash logs immediately
- Investigate scheduling issues
- Review resource constraints
- Immediate investigation required

**Validation:** Pod returns to Running state.
**Escalation:** Immediate L2; critical.

#### 6.8.3 [CDC][C2C] High CPU Usage Alert

**Dashboard:** cdc-cloud-alerts
**Condition:** Average CPU usage >60% for 1m
**Impact:** Performance degradation, potential throttling.

**Causes:** Increased workload, inefficient processing, resource limits.

**Actions:**
- Review workload distribution
- Check pod scaling configuration
- Adjust resource limits if needed
- Investigate processing efficiency

**Validation:** CPU usage <50%.
**Escalation:** L2 if sustained >15m.

#### 6.8.4 [CDC][C2C] High Memory Usage Alert

**Dashboard:** cdc-cloud-alerts
**Condition:** Memory usage >60% for 1m
**Impact:** Risk of OOM kills, performance issues.

**Causes:** Memory leaks, increased data volume, insufficient limits.

**Actions:**
- Check for memory leaks
- Review resource limits
- Optimize workloads as needed
- Scale if legitimate load increase

**Validation:** Memory usage <50%.
**Escalation:** L2 if approaching limits.

#### 6.8.5 [CDC][C2C] Network Inactive Alert

**Dashboard:** cdc-cloud-alerts
**Condition:** C2C network traffic near zero for 5m
**Impact:** Data flow interruption.

**Causes:** Network connectivity issues, pod health problems, upstream issues.

**Actions:**
- Verify data flow
- Check network connectivity
- Review pod health
- Investigate upstream dependencies

**Validation:** Network traffic resumes.
**Escalation:** L2 if no traffic >10m.

## 7. Common PromQL Queries for Troubleshooting

### Event Rates and EPS
```promql
# Total EPS across all sources
sum(rate(onprem_cdc_received_events_from_bloxone{ophid!="", source="bloxone"}[1m])) 
  + sum(rate(onprem_cdc_received_events_from_nios{ophid!=""}[1m]))

# EPS by source and ophid
sum by (ophid, source) (rate(onprem_cdc_received_events_from_bloxone{ophid!=""}[1m]))
sum by (ophid) (rate(onprem_cdc_received_events_from_nios{ophid!=""}[1m]))

# Pending events backlog
sum(onprem_cdc_pending_events{ophid!=""})
sum by (ophid) (onprem_cdc_pending_events{ophid!=""})
```

### Resource Utilization
```promql
# OnPrem CPU usage
(onprem_host_cpu_usage{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}) * 100

# OnPrem Memory usage
(onprem_host_memory_usage_used{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}) / 
(onprem_host_memory_usage_total{} * on(ophid) group_left(service) onprem_host_service_status{service=~"cdc.*"}) * 100

# Cloud pod CPU usage
(sum(rate(container_cpu_usage_seconds_total{namespace=~"cdc-.*", pod=~".*-.*-.*-.*"}[2m])) by (pod, container)) * 100

# Cloud pod memory usage
(sum(container_memory_working_set_bytes{namespace=~"cdc-.*", pod=~".*-.*-.*-.*"}) by (pod, container)) / 
(sum(container_spec_memory_limit_bytes{namespace=~"cdc-.*", pod=~".*-.*-.*-.*"}) by (pod, container)) * 100
```

### Pod Health and Restarts
```promql
# Pod restart events
increase(kube_pod_container_status_restarts_total{namespace=~"cdc-.*"}[5m])

# Pod status by phase
kube_pod_status_phase{namespace=~"cdc-.*"}

# Unhealthy pods
count(kube_pod_status_ready{namespace=~"cdc-.*", condition="false"})
```

### Service Health
```promql
# gRPC request rates
sum(irate(grpc_server_started_total{app=~"cdc.*"}[2m]))
sum by (grpc_method) (irate(grpc_server_started_total{app=~"cdc.*"}[2m]))

# HTTP error rates
sum(rate(nginx_ingress_controller_requests{namespace=~"cdc-.*", status=~"5.."}[1m])) / 
sum(rate(nginx_ingress_controller_requests{namespace=~"cdc-.*"}[1m])) * 100

# Flow status distribution
count by (account_id) (cdc_flow_status == 0)     # Review
count by (account_id) (cdc_flow_status == 0.5)   # Pending  
count by (account_id) (cdc_flow_status == 1)     # Active
```

## 8. Alert Severity Matrix

| Alert Type | Severity | Escalation Time | Auto-Recovery Expected |
|------------|----------|-----------------|----------------------|
| Pod Failed | Critical | Immediate | No |
| Service Down (5xx) | Critical | Immediate | No |
| No Events Received | Critical | 5m | No |
| No Active Flows | Critical | 5m | No |
| Host Inactive | High | 10m | No |
| High Resource Usage | High | 15m | Possible |
| Flow Status Degraded | High | 15m | Possible |
| Pod Restarts | Warning | 30m | Yes |
| High QPS | Warning | 30m | Yes |
| 4xx Errors | Warning | 60m | Possible |

## 9. Dashboard Quick Reference

| Dashboard | Purpose | Key Alerts |
|-----------|---------|------------|
| cdc-onprem-comprehensive-alert | OnPrem overview | Low EPS, Backlog, Sockets, Flows, QPS |
| cdc-onprem-resource-alerts | OnPrem resources | CPU, Memory, Disk usage |
| cdc-onprem-host-status-alerts | OnPrem host health | Host inactive |
| cdc-onprem-flow-status-alerts | OnPrem flow states | Flow degraded |
| cdc-onprem-container-timestamp-alerts | OnPrem data freshness | Timestamp lag |
| cdc-flow-alerts | Cloud flow service | Service down, restarts, errors |
| cdc-api-alerts | Cloud API service | API failures, restarts, errors |
| cdc-cloud-alerts | C2C data pipeline | Pod failures, resource usage, network |

## 10. Escalation Contacts and Procedures

### L1 → L2 Escalation
- **Trigger:** Alert persists beyond initial triage window
- **Information to provide:** Alert name, duration, attempted actions, current metrics
- **Channels:** PagerDuty, Slack #cdc-ops

### L2 → L3 Escalation  
- **Trigger:** Infrastructure/config changes don't resolve; suspected code issue
- **Information to provide:** Full diagnostic log, configuration changes attempted, error patterns
- **Channels:** PagerDuty escalation, Slack #cdc-engineering

### Emergency Escalation
- **Trigger:** Multiple critical alerts, customer impact, data loss risk
- **Contacts:** On-call SRE manager, Engineering manager
- **Channels:** Direct phone/SMS via PagerDuty

## 11. Recommendations for Alert Improvement

1. **Severity Normalization:** 
   - Replace "N/A" severity with proper Critical/High/Medium/Low classification
   - Remove duplicate Priority field in messages
   - Standardize on Grafana severity tags

2. **Alert Correlation:**
   - Implement alert grouping for related symptoms
   - Add dependency mapping (e.g., Host Inactive should suppress EPS alerts for that host)
   - Create composite alerts for common failure patterns

3. **Threshold Tuning:**
   - Review EPS threshold (300) based on historical data
   - Adjust resource usage thresholds based on normal operating ranges
   - Implement dynamic thresholds for time-of-day variations

4. **Notification Enhancement:**
   - Add alert context links to specific dashboards/panels
   - Include trending information (getting better/worse)
   - Add estimated impact and customer-facing effects

5. **Automation Opportunities:**
   - Auto-restart pods for certain failure types
   - Auto-scaling based on resource alerts
   - Automated log collection for escalated alerts

6. **Monitoring Gaps:**
   - Add alerts for certificate expiration
   - Monitor external dependency health
   - Track data quality metrics
   - Add business-level SLI/SLO monitoring

This runbook should be reviewed and updated quarterly based on operational experience and system evolution.
