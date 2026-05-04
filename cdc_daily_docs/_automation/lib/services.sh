#!/usr/bin/env bash
# Catalog of Infoblox CDC services. Bash 3.2 compatible (no assoc arrays).
# svc_info <slug> <field-index 1..4>
#   1=desc, 2=inputs, 3=outputs, 4=role

svc_info() {
  local slug="$1" idx="$2" row=""
  case "$slug" in
    cdc.agent)               row="On-prem CDC agent that runs the data pipeline lifecycle on customer hosts.|Local DNS/DHCP/RPZ logs|gRPC channel to cloud|Edge data collector" ;;
    cdc.api)                 row="External REST API surface for CDC management and configuration.|HTTPS clients|Backing services|Public API" ;;
    cdc.appbase)             row="Common base image and shared scaffolding for CDC microservices.|N/A|N/A|Base library / image" ;;
    cdc.automation.test)     row="End-to-end and integration test suite for CDC services.|Test fixtures|Test reports|QA" ;;
    cdc.common)              row="Shared Go libraries used across CDC services (logging, metrics, kafka helpers).|N/A|N/A|Shared library" ;;
    cdc.crds)                row="Kubernetes CustomResourceDefinitions used by CDC operators.|kubectl/operators|K8s API|K8s schema" ;;
    cdc.data.flow)           row="Core data flow orchestrator that wires producers, processors and consumers.|Kafka/gRPC|Kafka/processors|Pipeline orchestrator" ;;
    cdc.dns-in)              row="Ingests DNS query/response logs into the CDC pipeline.|DNS log streams|Kafka topics|Ingestion (in)" ;;
    cdc.etl)                 row="Transforms and enriches raw CDC events before downstream delivery.|Raw Kafka topics|Enriched Kafka topics|ETL" ;;
    cdc.flow.api.service)    row="Manages flow definitions and runtime state via API.|API clients|Flow registry|Control plane" ;;
    cdc.flume)               row="Apache Flume based legacy ingestion path retained for compatibility.|Syslog/file sources|Kafka|Legacy ingest" ;;
    cdc.grpc-in)             row="Ingests events over gRPC from on-prem agents.|gRPC streams from agents|Kafka topics|Ingestion (in)" ;;
    cdc.grpc-out)            row="Streams CDC events out over gRPC to subscribed consumers.|Kafka topics|gRPC subscribers|Egress (out)" ;;
    cdc.http-out)            row="Delivers CDC events to HTTP/HTTPS webhook endpoints.|Kafka topics|Customer HTTP endpoints|Egress (out)" ;;
    cdc.infraservice)        row="Infrastructure facing service for cluster-level CDC concerns.|K8s/cloud APIs|CDC services|Infra glue" ;;
    cdc.kafka.flow.processor)row="Kafka stream processor implementing per-flow business logic.|Kafka topics|Kafka topics|Processing" ;;
    cdc.onboarding)          row="Customer onboarding workflows for enabling CDC.|Onboarding API|CDC config store|Onboarding" ;;
    cdc.pocs)                row="Proof-of-concept code and experiments.|N/A|N/A|R&D" ;;
    cdc.reporting-out)       row="Pushes events to internal reporting/analytics sinks.|Kafka topics|Reporting backend|Egress (out)" ;;
    cdc.rest-out)            row="Delivers CDC events to customer REST endpoints with auth and retries.|Kafka topics|Customer REST APIs|Egress (out)" ;;
    cdc.rpz-in)              row="Ingests Response Policy Zone (RPZ) hit/feed events.|RPZ event stream|Kafka topics|Ingestion (in)" ;;
    cdc.siem-out)            row="Delivers CDC events to SIEM platforms (CEF/LEEF formatting).|Kafka topics|SIEM collectors|Egress (out)" ;;
    cdc.splunk-out)          row="Delivers CDC events to Splunk via HEC.|Kafka topics|Splunk HEC|Egress (out)" ;;
    cdc.splunkforwarderbase) row="Base image for Splunk forwarder based delivery paths.|N/A|N/A|Base image" ;;
    cdc.syslog-out)          row="Delivers CDC events to Syslog endpoints (TCP/UDP/TLS).|Kafka topics|Syslog servers|Egress (out)" ;;
    cdc.wapi-in)             row="Ingests events from the Infoblox WAPI source.|WAPI source|Kafka topics|Ingestion (in)" ;;
    *)                       row="CDC component.|N/A|N/A|Component" ;;
  esac
  echo "$row" | awk -F'|' -v i="$idx" '{print $i}'
}

# Ordered list of service slugs (stable iteration order). Space-separated for
# bash-3.2 compatibility (no assoc arrays needed; word-split when iterating).
SERVICE_ORDER="cdc.agent cdc.api cdc.appbase cdc.common cdc.crds cdc.data.flow cdc.flow.api.service cdc.infraservice cdc.onboarding cdc.dns-in cdc.grpc-in cdc.rpz-in cdc.wapi-in cdc.flume cdc.etl cdc.kafka.flow.processor cdc.grpc-out cdc.http-out cdc.rest-out cdc.siem-out cdc.splunk-out cdc.syslog-out cdc.reporting-out cdc.splunkforwarderbase cdc.automation.test cdc.pocs"
