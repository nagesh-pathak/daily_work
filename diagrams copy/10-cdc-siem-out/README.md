# CDC SIEM-Out (cdc.siem-out)

## Overview
Health check for SIEM forwarding via Splunk UF. On-prem only. Like splunk-out but reads CEF (ArcSight) and LEEF (QRadar) formatted files from /data/out/siem/ directories. Base image: cdc.splunkforwarderbase v2.1.3.

## Architecture
Flume DnsToCefLeef/RpzToCefLeef sinks → /data/out/siem/{cef,leef} → Splunk UF monitors → forwards to ArcSight/QRadar

## Data Flow
1. Flume writes CEF/LEEF formatted files to /infoblox/data/out/siem/
2. Splunk UF watches directories via inputs.conf
3. UF forwards to customer's SIEM (ArcSight or QRadar)
4. cdc.siem-out monitors UF health on port 8089

## Output Formats

| Format | Full Name | Target SIEM | Example Header |
|--------|-----------|-------------|----------------|
| CEF | Common Event Format | HP ArcSight | `CEF:0\|Infoblox\|BloxOne\|1.0\|DNS Query\|DNS Response\|3\|src=... dst=... cs1=...` |
| LEEF | Log Event Extended Format | IBM QRadar | `LEEF:2.0\|Infoblox\|BloxOne\|1.0\|DNS Query\|src=... dst=... devTime=...` |

## Data Directories

| Directory | Description |
|-----------|-------------|
| /infoblox/data/out/siem/nios/dns/cef/ | NIOS DNS in CEF |
| /infoblox/data/out/siem/nios/dns/leef/ | NIOS DNS in LEEF |
| /infoblox/data/out/siem/nios/rpz/cef/ | RPZ in CEF |
| /infoblox/data/out/siem/nios/rpz/leef/ | RPZ in LEEF |
| /infoblox/data/out/siem/bloxone/cef/ | BloxOne in CEF |
| /infoblox/data/out/siem/bloxone/leef/ | BloxOne in LEEF |

## Health Check
- HTTP :10001/health
- TLS mutual auth to Splunk UF port 8089
- Same mechanism as splunk-out

## Differences from splunk-out

| Aspect | splunk-out | siem-out |
|--------|-----------|----------|
| Data directory | /data/out/splunk/ | /data/out/siem/ |
| Data format | Raw CSV | CEF / LEEF |
| Target | Splunk indexers | ArcSight / QRadar |
| Base image | cdc.splunkforwarderbase | cdc.splunkforwarderbase |
| Health check | Same | Same |

## Dependencies
- cdc.splunkforwarderbase v2.1.3, Splunk UF 9.1.0
- Flume (DnsToCefLeef, RpzToCefLeef sinks)
- Config Manager, cdc.agent
