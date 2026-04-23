# CDC DNS-In (cdc.dns-in)

## Overview
DNS capture ingestion from NIOS via SSH/SCP. On-prem only. Monitors /infoblox/data/in/scp/ for captured-dns-*.gz files, validates MD5, decompresses, stages to /infoblox/data/in/flume/dns/ for Flume SpoolDir source.

## Data Flow
NIOS DNS capture → SCP transfer (port 22) → Landing dir → MD5 validate → gzip decompress → Flume staging dir

## SSH/SCP Configuration
- OpenSSH server 9.8p1 on port 22
- Key-based authentication (no passwords)
- Landing directory: /infoblox/data/in/scp/
- File pattern: captured-dns-{member}-{timestamp}.gz
- MD5 file: captured-dns-{member}-{timestamp}.gz.md5

## Validation Steps
1. Wait for both .gz and .md5 files to arrive
2. Compute MD5 of .gz file
3. Compare against .md5 file
4. Match: decompress → stage to flume/dns/
5. Mismatch: log error, move to failed/

## Output
- Staging dir: /infoblox/data/in/flume/dns/
- Consumed by Flume SpoolDir source

## Dependencies
- NIOS DNS capture agent, Flume SpoolDirSource, cdc.agent (10x multiplication factor), Config Manager
- Docker: Alpine Linux + OpenSSH 9.8p1, supervisord manages sshd + file processor
