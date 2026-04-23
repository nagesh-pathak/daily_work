# CDC RPZ-In (cdc.rpz-in)

## Overview
RPZ syslog ingestion from NIOS via stunnel TLS. On-prem only. NIOS sends RPZ hit events as syslog over TLS (port 6514). Stunnel terminates TLS, rsyslog parses, SyslogInterceptorBuilder extracts RPZ fields, stages for Flume.

## Data Flow
NIOS RPZ syslog (TLS:6514) → Stunnel (6514→50514) → rsyslog → SyslogInterceptor → /data/in/flume/rpz/ → Flume multiport_syslogtcp

## Stunnel TLS
- Listens: port 6514 (TLS)
- Forwards: localhost:50514 (plaintext)
- Cert: /infoblox/etc/certs/syslog-cert.pem
- Key: /infoblox/etc/certs/syslog-key.pem
- CA: /infoblox/etc/certs/ca.pem

## RPZ Event Fields
qname, rpz_zone, rpz_action (NXDOMAIN/PASSTHRU/etc), client_ip, member, timestamp

## Dependencies
- NIOS syslog agent, stunnel, rsyslog, Flume multiport_syslogtcp source (port 514), cdc.agent, Config Manager
- Docker: Alpine Linux + stunnel + rsyslog, supervisord
