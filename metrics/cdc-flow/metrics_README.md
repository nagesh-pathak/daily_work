# CDC Flow API Service Metrics Documentation

This document provides comprehensive information about the metrics architecture, flow sequence, and data processing in the CDC Flow API Service.

## Overview

The CDC Flow API Service uses a robust metrics system to monitor the health and performance of data flows between sources and destinations. The service integrates with Prometheus for metrics collection and provides real-time status information about the data flow pipelines.

## Metrics Architecture (metrics_architecture.puml)

This diagram illustrates the overall architecture of the metrics system:

- **CDC Flow API Service**: The main service that manages flows, collects metrics, and evaluates status
- **Pod Services**: The operational pods (grpc_in, syslog_out, soar_light, http_out) that expose metrics endpoints
- **Prometheus**: Collects and stores metrics from all components
- **Dashboard**: Visualizes metrics and provides alerting capabilities

## Metrics Flow Sequence (metrics_sequence.puml)

This sequence diagram shows the temporal flow of metrics collection and status determination:

1. **Metrics Collection Initialization**: How the system sets up metrics collection
2. **Metrics Collection Cycle**: The ongoing scraping of metrics by Prometheus
3. **Flow Status Determination**: How flow status is calculated based on metrics
4. **Status Update on Metrics Change**: How changes in metrics affect status
5. **Error Handling**: How errors are detected and processed

## Metrics Data Flow (metrics_data_flow.puml)

This diagram visualizes the flow of metrics data through the system:

- **Data Producers**: Components that generate metrics
- **Metrics Collection**: How Prometheus collects and stores the data
- **Metrics Processing**: How metrics are processed to determine status
- **Visualization**: How metrics are presented in dashboards

## Status State Machine (metrics_status_state_machine.puml)

This diagram details the state machine for flow status:

- **Intermediate State**: New flow or service starting, no data available yet
- **Active State**: Normal operation with data flowing and no errors
- **Inactive State**: Error conditions detected, requiring intervention

## Components Integration (metrics_components.puml)

This diagram shows how the different components of the CDC Flow API Service interact with the metrics system:

- **API Server**: Handles API requests
- **Flow Controller**: Manages Kubernetes resources
- **Status Manager**: Determines flow status based on metrics
- **Metrics Collector**: Interfaces with Prometheus
- **Config API Server**: Provides configuration information

## Key Metrics

### API Service Metrics
- **cloud_cdc_api_request_count**: Count of API requests
- **cloud_cdc_api_request_duration**: Latency of API requests
- **cloud_cdc_api_error_count**: Count of API errors

### Pod Service Metrics
- **cloud_cdc_timestamp**: Timestamp of last event processed
- **cloud_cdc_pod_error**: Error counter for pod services

## Flow Status Determination

Flow status is determined by examining both source and destination service metrics:

- **Active**: No errors, recent timestamps
- **Inactive**: Error count > 0 or connection issues
- **Intermediate**: Service starting or no data available

The status determination logic is implemented in the `determineFlowStatus()` function in `cloud_metrics.go`.

## Metrics Collection

Metrics are collected from:

1. CDC Flow API Service (port 8080)
2. Pod services (port 9152)

Prometheus scrapes these endpoints at regular intervals and stores the time-series data.
