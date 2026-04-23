# CDC Flume (cdc.flume)

## Overview
Apache Flume 1.9.0 central data transformation and routing engine. On-prem only. The heart of on-prem CDC pipeline — receives data from dns-in, rpz-in, wapi-in sources; transforms into CSV, CEF, LEEF, JSON, Parquet; routes to splunk-out, siem-out, rest-out, syslog-out destinations.

## Architecture
Sources (SpoolDir / multiport_syslogtcp) → Memory Channels → Java Custom Sinks → Output directories

Jinja2 template generates flume.conf. Supervisor manages 6 processes.

## Flume Sources
1. DNS SpoolDir Source: /infoblox/data/in/flume/dns/ (from cdc.dns-in)
2. RPZ Multiport SyslogTCP: port 514 (from cdc.rpz-in → rsyslog)
3. IPMeta SpoolDir Source: /infoblox/data/in/flume/ipmeta/ (from cdc.wapi-in)

## Memory Channels (capacity)
- dns-to-csv: 500,000 events
- dns-to-cefleef: 500,000 events
- dns-to-cloud: 1,000,000 events
- rpz-to-csv: 4,000,000 events
- rpz-to-cefleef: 4,000,000 events
- rpz-to-cloud: 4,000,000 events
- ipmeta-to-cloud: 500,000 events

## Custom Java Sinks
| Sink | Output Directory | Format | Consumer |
|------|-----------------|--------|----------|
| DnsToCsv | /data/out/splunk/nios/dns/ | CSV | cdc.splunk-out |
| DnsToCefLeef | /data/out/siem/nios/dns/{cef,leef}/ | CEF/LEEF | cdc.siem-out |
| DnsToJson | /data/out/syslog/nios/dns/ | JSON | cdc.syslog-out |
| CloudFileSink | /data/out/cloud/{dns,rpz,ipmeta}/ | Parquet | cdc.rest-out |
| RpzToCsv | /data/out/splunk/nios/rpz/ | CSV | cdc.splunk-out |
| RpzToCefLeef | /data/out/siem/nios/rpz/{cef,leef}/ | CEF/LEEF | cdc.siem-out |

## Configuration Generation
- Jinja2 templates generate flume.conf dynamically
- Variables from CDC API / infraservice config
- Dynamic source/channel/sink wiring per flow
- Published to cm-flume topic for Config Manager delivery

## Supervisor Processes
1. flume-dns — DNS pipeline
2. flume-rpz — RPZ pipeline
3. flume-ipmeta — IPMeta pipeline
4. flume-http — HTTP output (optional)
5. config-watcher — Config reload

## Technology Stack
- Apache Flume 1.9.0 (data pipeline)
- Java 11 (custom sinks)
- Jinja2/Python (config generation)
- supervisord (process management)

## Dependencies
- cdc.dns-in, cdc.rpz-in, cdc.wapi-in (sources)
- cdc.infraservice (config management)
- cdc.api (flume config generation)
- Config Manager (config delivery via cm-flume-{env})

Tables for channels, sinks, processes.
