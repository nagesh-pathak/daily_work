# CDC WAPI-In (cdc.wapi-in)

## Overview  
IPAM metadata collector via WAPI REST API polling. On-prem only. Polls NIOS Grid Master for IPAM objects (leases, fixed addresses, hosts, DNS records, DHCP ranges). Incremental change tracking via sequence IDs. Outputs Avro files for cloud upload.

## Data Flow
NIOS WAPI REST → Poller (incremental tracking) → Avro serializer → /data/out/cloud/ipmeta/ → cdc.rest-out uploads

## WAPI Objects Polled

| Object Type | Key Fields | WAPI Endpoint |
|---|---|---|
| DHCP Leases | IP, MAC, hostname, state, binding_state | /wapi/v2.x/lease |
| Fixed Addresses | IP, MAC, name, match_client, network_view | /wapi/v2.x/fixedaddress |
| Host Records | hostname, IPs, aliases, zone, view | /wapi/v2.x/record:host |
| DNS Records | A, AAAA, CNAME, PTR, MX, TXT, SRV | /wapi/v2.x/record:{type} |
| DHCP Ranges | start_addr, end_addr, network, options | /wapi/v2.x/range |

## Incremental Change Tracking
- Initial poll: full snapshot of all objects
- Subsequent: delta changes via sequence IDs
- 7-day cache validity
- Auto-refresh snapshot after cache expiry

## Avro Output

| Field | Description |
|---|---|
| File pattern | ipmeta-{timestamp}-{sequence_id}.avro |
| Schema | Per object type (embedded in Avro) |
| Snapshot flag | is_snapshot (true for full snapshots) |
| Output dir | /infoblox/data/out/cloud/ipmeta/ |

## Avro Fields by Object Type

| Object | Avro Fields |
|---|---|
| DHCP Lease | ip_address, mac_address, hostname, state, binding_state, starts, ends, network, network_view |
| Fixed Address | ip_address, mac_address, name, match_client, network_view, comment, extattrs |
| Host Record | hostname, ipv4addrs, ipv6addrs, aliases, zone, view, ttl, comment |
| DNS Record | name, type, rdata, zone, view, ttl, comment |
| DHCP Range | start_addr, end_addr, network, network_view, options, member, failover_association |

## Configuration
- NIOS Grid Master IP/hostname, WAPI version v2.x
- Auth: username/password (Vault encrypted)
- TLS certificate validation

## Dependencies
- NIOS WAPI REST API, cdc.rest-out (cloud upload), cdc.agent (cleanup), Config Manager
