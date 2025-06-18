[6/17 Tue]
    [] We need to build this in CDC
        https://grafana.csp.infoblox.com/d/ol7Ty49nk/ss-ops-onprem-cdc?orgId=1&var-account_id=894&var-ophid=fee3451d106c744bc70001504f702ad9
    [] we need to bil this as well
        https://support-grafana.csp.infoblox.com/d/Wh3NGPm4z/onprem-host-status?orgId=1&var-ophid=fee3451d106c744bc70001504f702ad9
    [] Get account name from account-id
    [] 

[6/12 Thur]
    [] need to show the total disk usage along with infoblox usage
    [] We need another filter along with top 20
    [] Get account-id/ophid by customer name
    [] Get ophid from account-id
    [] How to find the event log/data not pulling cases based on events metrics 

[6/11 Wed]
    [] Each service level error count for the selected date range
    [] Add pie chart for that along with table information
    [] Total Hosts (healthy + unhealthy)
        [] Hosts in Review-Details
        [] Healthy Hosts
        [] Host in disconnected state
        [] Hosts with CDC <= 4 cores and <= 8 GB RAM <= 128 GB Hard Disk
        https://grafana.csp.infoblox.com/d/XgYO2dZ7k/onprem-hosts-health-stats?orgId=1
    [] Total number of CDC enabled Accounts
    [] Need more details about total RAM size, used size and %
    [] Same is required for memory and disk usage
        https://grafana.csp.infoblox.com/d/c23f2fa8-25df-4a36-9991-73775a171780/onprem-host-resources?orgId=1 
    [] Container open sockets
        https://grafana.csp.infoblox.com/d/f3e2d417-4e1a-45d7-81f2-a21f7264df84/onprem-container-metrics-overall?orgId=1
    [] Stale flows [flows created, but ther is no data flow]

    [] References
        https://grafana.csp.infoblox.com/d/c23f2fa8-25df-4a36-9991-73775a171780/onprem-host-resources?orgId=1 
        https://grafana.csp.infoblox.com/d/XgYO2dZ7k/onprem-hosts-health-stats?orgId=1

[6/2 Mon]
    [] Add a index page for grafana links
    [X] Prepare table for above threshold disk/cpu/memory usage [ETA: 6/2]
    [X] Tracking usage of cpu/memory/disk
    [X] Create tables for now for both threshold and track usage - Only for onprem changes
    [X] Create user stories, provide effort estimations and allocate to iterations
    [X] Add destination RPM to track pannel, so that we can ask customer to come up with solution

[5/28 Wed]
    Phase-1
        [X] Disk Usage
            [1] Disk usage > 50% (vs Total Disk Size)
            [2] Disk usage tracking (> from last 3 hours)
        [X] CPU Usage
            [1] CPU usage > 60% (vs Total Cores)
            [2] CPU usage tracking (> from last 1 hours)
        [X] Memory Usage
            [1] Memory usage > 50% (vs Total RAM Size)
            [2] Memory usage tracking (> from last 1 hours)
        [...] Flow Status
            [] We need total count and % w.r.t each status
            Count
                [] Total number of flows in "Review Details"
                [] Total number of flows in "Disabled"
                [] Total number of flows in "Pending Configuration Push"
                [] Total number of flows in "Online"
        [X] How many customers enabled CDC and how many hosts ?
            - Need two things [one to show overall and another to show in table form w.r.t account filter]
        [X] Move CDC Flow & CDC API from onprem-monitoring
        [] Add monitoring & Alerting for CrashLoopBackOff | ImagePullBackOff | Restart
    [] Phase-2
        [] 

[5/26 Mon]
    [] Dev Integration Validation - NIOS Multiple flows to same destination
    [] Share the latest images to QA for integration validation
    [] KT to QA - NIOS Multiple flows to same destination
    [X] Explore prometheus/grafana for telemetrics
    [X] Prepare a document for all supported metrics - Existing
    [] Prepare a plan for new metrics
        [] Event Metrics
            [] Flow specific event metrics
        [] Size Metrics
            [] Flow specific size metrics
        [] Volume Metrics
            [] CDC host specific metrics
        [] CPU Metrics
            [] Above threshold CPU consumption
        [] Memory Metrics
        [...] Flow Status Metrics
        [X] Customer Usage Metrics - Feature Adoption
        [] Service Log Metrics
        [...] Pod Restart Metrics (Cloud & OnPrem)
        [...] ImagePullBackOff Metrics (Cloud & OnPrem)
        [] OOM Metrics
        [X] EPS/QPS Metrics
        [X] Service Status(Healthy/UnHealthy) Metrics
    [...] Execute the plan

References:

    https://grafana.csp.infoblox.com/dashboards/f/4fAaH9Rnk/onprem-monitoring

    https://grafana.csp.infoblox.com/d/4JWsWyUf/upgrade-policy?orgId=1
        - All errors from service
        - Number of goroutines
        - Errors: 4XX & 5XX
    https://grafana.csp.infoblox.com/d/jT2aIYn4z/status-service?orgId=1
        - 
    https://grafana.csp.infoblox.com/d/XgYO2dZ7k/onprem-hosts-health-stats?orgId=1
        - Hosts with > 80% CPU/Memory/Volume

    https://grafana.csp.infoblox.com/d/c9e86cca-2b15-446c-b82f-7088d49954c7/any-k8s-namespace-monitor?orgId=1&var-namespace=cdc-flow&var-horizontalpodautoscaler=All&var-deployment=cdc-api&var-deployment=cdc-flow&var-deployment=cdc-flow-hostapp-sync&var-deployment=cdc-status-reporter&var-container=cdc-flow-api


    https://grafana.csp.infoblox.com/d/RHSwiHXWk/dapr-system-services-dashboard?orgId=1&refresh=5s

    https://grafana.csp.infoblox.com/d/VyLLTfaHl/entitlements-dashboard?orgId=1

    https://grafana.csp.infoblox.com/d/6UPddewvz/hostapp-dashboard?orgId=1

    https://grafana.csp.infoblox.com/d/Jc15iPYAl/identity-dashboard?orgId=1

    https://grafana.csp.infoblox.com/d/yDhc2iP4z/infrastructure-extension?orgId=1&refresh=1m

    https://grafana.csp.infoblox.com/d/S1Iq4uHnk/news?orgId=1

    https://grafana.csp.infoblox.com/d/ZqSqXpg4z/poseidon-detectors?orgId=1

    https://grafana.csp.infoblox.com/d/7_VGtoLma/grpc-dashboard?orgId=1

    https://grafana.csp.infoblox.com/dashboards
 