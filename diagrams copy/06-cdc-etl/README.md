# CDC ETL Library (cdc.etl)

## Overview

Standalone Parquet-to-CSV transformation Go library. **NOT a microservice** — no Kafka, no Dapr, no gRPC server. Imported as a package by `cdc.grpc-in` and `cdc.flume` for data transformation.

```
┌─────────────────────────────────────────────────────────┐
│                      cdc.etl                            │
│              (Pure Go Library - No Runtime)              │
│                                                         │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────┐ │
│  │   Parquet    │───▶│  Worker Pool  │───▶│  CSV Writer│ │
│  │   Reader     │    │ (10 goroutines)│   │ (40K/file) │ │
│  └─────────────┘    └──────────────┘    └────────────┘ │
│        ▲                                      │         │
│        │                                      ▼         │
│  ┌─────────────┐                     ┌────────────────┐ │
│  │ Column Reader│                    │ /data/out/*.csv │ │
│  │ Row Reader   │                    └────────────────┘ │
│  └─────────────┘                                        │
└─────────────────────────────────────────────────────────┘
        ▲                                      │
        │  Imported by                         │
   ┌────┴─────┐    ┌──────────┐               │
   │cdc.grpc-in│   │ cdc.flume │               │
   └──────────┘    └──────────┘               │
```

## Architecture

- Pure Go library with two reader approaches: **Column Reader** and **Row Reader**
- Worker pool of **10 goroutines** for parallel processing
- Output: **40,000 records** per CSV file (configurable)
- Uses **buffered channels** for producer-consumer pattern

### Processing Pipeline

```
┌──────────────┐     ┌────────────┐     ┌──────────────┐     ┌─────────────┐     ┌──────────────┐
│ 1. Input     │────▶│ 2. Reader  │────▶│ 3. Worker    │────▶│ 4. Transform│────▶│ 5. Output    │
│ Parquet Files│     │ Col / Row  │     │ Pool (10)    │     │ Map & Convert│    │ CSV (40K ea) │
│ (columnar)   │     │ Parse Schema│    │ Parallel Proc│     │ Flag Extract │    │ /data/out/   │
└──────────────┘     └────────────┘     └──────────────┘     └─────────────┘     └──────────────┘
```

## Reader Approaches

### 1. Column Reader

Reads Parquet files **column-by-column**, efficient for selective field extraction. Used primarily for DNS log processing.

```go
// Column reader example — reads specific columns from Parquet
func processWithColumnReader(parquetFile string) ([][]string, error) {
    fr, err := local.NewLocalFileReader(parquetFile)
    if err != nil {
        return nil, fmt.Errorf("failed to open parquet file: %w", err)
    }
    defer fr.Close()

    pr, err := reader.NewParquetColumnReader(fr, 4) // 4 parallel readers
    if err != nil {
        return nil, fmt.Errorf("failed to create column reader: %w", err)
    }
    defer pr.ReadStop()

    numRows := int(pr.GetNumRows())
    // Read specific columns by name
    qnames, _, _, err := pr.ReadColumnByPath("parquet_go_root.qname", numRows)
    qtypes, _, _, err := pr.ReadColumnByPath("parquet_go_root.qtype", numRows)
    rcodes, _, _, err := pr.ReadColumnByPath("parquet_go_root.rcode", numRows)

    records := make([][]string, numRows)
    for i := 0; i < numRows; i++ {
        records[i] = []string{
            qnames[i].(string),
            qtypes[i].(string),
            rcodes[i].(string),
        }
    }
    return records, nil
}
```

### 2. Row Reader

Reads Parquet files **row-by-row** for full record processing. Used for complex transformation scenarios.

```go
// Row reader example — reads full rows from Parquet
type DNSRecord struct {
    Qname    string `parquet:"name=qname, type=BYTE_ARRAY"`
    Qtype    string `parquet:"name=qtype, type=BYTE_ARRAY"`
    Rcode    string `parquet:"name=rcode, type=BYTE_ARRAY"`
    ClientIP string `parquet:"name=client_ip, type=BYTE_ARRAY"`
    Severity string `parquet:"name=severity, type=BYTE_ARRAY"`
}

func processWithRowReader(parquetFile string) ([]DNSRecord, error) {
    fr, err := local.NewLocalFileReader(parquetFile)
    if err != nil {
        return nil, fmt.Errorf("failed to open parquet file: %w", err)
    }
    defer fr.Close()

    pr, err := reader.NewParquetReader(fr, new(DNSRecord), 4)
    if err != nil {
        return nil, fmt.Errorf("failed to create row reader: %w", err)
    }
    defer pr.ReadStop()

    numRows := int(pr.GetNumRows())
    records := make([]DNSRecord, numRows)
    if err = pr.Read(&records); err != nil {
        return nil, fmt.Errorf("failed to read records: %w", err)
    }
    return records, nil
}
```

## DNS Log Fields

### Boolean Flags (16 total)

| Flag | Description |
|------|-------------|
| `qr` | Query/Response indicator |
| `aa` | Authoritative Answer |
| `tc` | Truncation |
| `rd` | Recursion Desired |
| `ra` | Recursion Available |
| `ad` | Authenticated Data |
| `cd` | Checking Disabled |
| `do` | DNSSEC OK |
| `ecs` | EDNS Client Subnet |
| `ede` | Extended DNS Errors |
| `z` | Reserved bit |
| `rcode` | Response Code |
| `opcode` | Operation Code |
| `qclass` | Query Class |
| `qtype` | Query Type |
| `protocol` | Transport Protocol |

### Resource Record Arrays (6 types)

Each DNS response can contain up to 6 resource record sections:

| RR Section | Description |
|------------|-------------|
| `answer` | Answer records for the query |
| `authority` | Authoritative nameserver records |
| `additional` | Additional helpful records |
| `question` | Original question section |
| `opt` | EDNS OPT pseudo-records |
| `tsig` | Transaction Signature records |

Each resource record contains:

```go
type ResourceRecord struct {
    Name  string `parquet:"name=name, type=BYTE_ARRAY"`
    Type  string `parquet:"name=type, type=BYTE_ARRAY"`
    Class string `parquet:"name=class, type=BYTE_ARRAY"`
    TTL   int64  `parquet:"name=ttl, type=INT64"`
    Rdata string `parquet:"name=rdata, type=BYTE_ARRAY"`
}
```

## Supported Data Types

| Data Type | Source | Key Fields |
|-----------|--------|------------|
| `TD_QUERY_RESP_LOG` | BloxOne Threat Defense DNS | `qname`, `qtype`, `rdata`, `rcode`, `client_ip` |
| `TD_THREAT_FEEDS_HITS_LOG` | Threat feed matches | `threat_class`, `feed_name`, `confidence` |
| `DDI_QUERY_RESP_LOG` | BloxOne DDI DNS | `qname`, `qtype`, `dns_view`, `client` |
| `DDI_DHCP_LEASE_LOG` | DHCP lease events | `lease_ip`, `mac`, `hostname`, `state` |
| `AUDIT_LOG` | System audit | `user`, `action`, `resource`, `timestamp` |
| `SERVICE_LOG` | Service events | `service`, `level`, `message` |
| `SOC_INSIGHTS` | SOC insights | `insight_id`, `severity`, `indicators` |
| `SOC_INSIGHTS_V2` | SOC insights v2 | Enhanced insight fields |

### Data Type Configuration Example

```go
// Each data type maps to a specific Parquet schema and CSV column layout
var DataTypeConfig = map[string]TypeConfig{
    "TD_QUERY_RESP_LOG": {
        ReaderType:    ColumnReader,
        BatchSize:     40000,
        OutputDir:     "/data/out/td_dns/",
        SchemaFields:  tdQueryRespFields,
        BooleanFlags:  []string{"qr", "aa", "tc", "rd", "ra", "ad", "cd", "do"},
        RRArrays:      []string{"answer", "authority", "additional"},
    },
    "DDI_DHCP_LEASE_LOG": {
        ReaderType:    RowReader,
        BatchSize:     40000,
        OutputDir:     "/data/out/ddi_dhcp/",
        SchemaFields:  ddiDhcpLeaseFields,
        BooleanFlags:  nil,
        RRArrays:      nil,
    },
    // ... additional data types
}
```

## Worker Pool Pattern

The ETL library uses a producer-consumer pattern with buffered channels:

```go
const (
    NumWorkers     = 10    // Worker pool size
    RecordsPerFile = 40000 // Records per output CSV
    ChannelBuffer  = 1000  // Buffered channel size
)

func TransformParquetToCSV(inputFile, outputDir, dataType string) error {
    config := DataTypeConfig[dataType]
    recordCh := make(chan []string, ChannelBuffer)

    // Start workers (consumers)
    var wg sync.WaitGroup
    for i := 0; i < NumWorkers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            processRecords(workerID, recordCh, config)
        }(i)
    }

    // Producer: read Parquet and send records to channel
    switch config.ReaderType {
    case ColumnReader:
        readColumnar(inputFile, recordCh, config)
    case RowReader:
        readRows(inputFile, recordCh, config)
    }
    close(recordCh)

    wg.Wait()
    return nil
}
```

## CSV Output Format

```go
// Writer batches records into CSV files, each with up to 40K rows
type CSVWriter struct {
    outputDir  string
    batchSize  int
    fileIndex  int
    buffer     [][]string
}

func (w *CSVWriter) Write(record []string) error {
    w.buffer = append(w.buffer, record)
    if len(w.buffer) >= w.batchSize {
        return w.flush()
    }
    return nil
}

func (w *CSVWriter) flush() error {
    filename := fmt.Sprintf("%s/output_%05d.csv", w.outputDir, w.fileIndex)
    f, err := os.Create(filename)
    if err != nil {
        return err
    }
    defer f.Close()

    csvWriter := csv.NewWriter(f)
    defer csvWriter.Flush()

    for _, record := range w.buffer {
        if err := csvWriter.Write(record); err != nil {
            return err
        }
    }
    w.buffer = w.buffer[:0]
    w.fileIndex++
    return nil
}
```

Output file structure:
```
/data/out/
├── td_dns/
│   ├── output_00000.csv    # 40,000 records
│   ├── output_00001.csv    # 40,000 records
│   └── output_00002.csv    # remaining records
├── ddi_dhcp/
│   └── output_00000.csv
├── audit/
│   └── output_00000.csv
└── soc_insights/
    └── output_00000.csv
```

## Consumers

| Consumer | Usage | Context |
|----------|-------|---------|
| `cdc.grpc-in` | Imports ETL for cloud-to-CSV transformation | Receives Parquet via gRPC streaming, calls ETL to produce CSV |
| `cdc.flume` | Uses ETL for on-prem Parquet processing | Processes S3-downloaded Parquet files through ETL pipeline |

### Import Example

```go
// In cdc.grpc-in or cdc.flume:
import "github.com/Infoblox-CTO/cdc.etl/etl"

func handleParquetFile(filePath, dataType string) error {
    outputDir := fmt.Sprintf("/data/out/%s/", dataType)
    return etl.TransformParquetToCSV(filePath, outputDir, dataType)
}
```

## Key Packages

| Package | Path | Responsibility |
|---------|------|----------------|
| `etl/` | `cdc.etl/etl/` | Core transformation engine — orchestrates readers, workers, and writers |
| `reader/` | `cdc.etl/reader/` | Column and row Parquet readers with schema-aware parsing |
| `writer/` | `cdc.etl/writer/` | CSV file writer with configurable batch size (default 40K) |
| `schema/` | `cdc.etl/schema/` | Parquet schema definitions for each supported data type |

## Summary

```
cdc.etl is a focused transformation library:

  Input:   Apache Parquet (columnar storage format)
  Process: Column/Row reader → 10-goroutine worker pool → field mapping
  Output:  CSV files (40K records each) in /data/out/
  
  NOT a service — no HTTP, no gRPC, no Kafka, no Dapr
  Used by: cdc.grpc-in (cloud) and cdc.flume (on-prem)
```
