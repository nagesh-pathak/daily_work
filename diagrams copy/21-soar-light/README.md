# Scheduled Source Support for SOAR-Light Cloud-to-Cloud (C2C) Flows

## Requirements Document

| Field | Value |
|-------|-------|
| **Feature** | Enable `SOURCE_SCHEDULE` for C2C SOAR-Light flows |
| **Components** | `cdc.flow.api.service`, `soar-light` |
| **Branches** | `cdc.flow.api.service`: `c2c-schedule-support-v296` · `soar-light`: `soar-schedule-support-043` |
| **Status** | Implementation complete — both components modified and build-verified |
| **Date** | April 2026 |

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Current Behavior](#2-current-behavior)
3. [Proposed Behavior](#3-proposed-behavior)
4. [Scope](#4-scope)
5. [Technical Analysis](#5-technical-analysis)
6. [Implementation Details](#6-implementation-details)
7. [Kubernetes Resource Comparison](#7-kubernetes-resource-comparison)
8. [End-to-End Flow](#8-end-to-end-flow)
9. [Impact Summary](#9-impact-summary)
10. [Test Validation](#10-test-validation)
11. [Open Issues](#11-open-issues)
12. [Architecture Diagrams](#12-architecture-diagrams)

---

## 1. Problem Statement

SOAR-Light supports two script execution modes:

| Mode | Interface | Trigger | Source Type |
|------|-----------|---------|-------------|
| **Event-driven** | `IEventHandler` | Fired per Kafka event | `SOURCE_BLOXONE` |
| **Scheduled** | `IScheduler` | Fired on cron schedule | `SOURCE_SCHEDULE` |

Scheduled source (`SOURCE_SCHEDULE`) is currently **blocked for C2C flows** by an explicit validation check in `cdc.flow.api.service`. It is only available for on-prem deployments.

The block exists because the C2C deployment model creates **two pods per flow** — a `grpc-in` pod (reads Kafka events) and a `soar-light` pod (runs Python). For scheduled flows, the `grpc-in` pod has no function since there are no events to consume.

**Requirement**: Allow `SOURCE_SCHEDULE` in C2C by creating only the `soar-light` pod (skipping `grpc-in`), eliminating wasted resources.

---

## 2. Current Behavior

### 2.1 C2C Flow Resource Creation

For every C2C flow, `cdc.flow.api.service` creates:

| Resource | Name Pattern | Purpose |
|----------|-------------|---------|
| ConfigMap | `cdc-grpc-in-cm-{accountId}-{flowId}` | grpc-in pod configuration |
| StatefulSet | `cdc-grpc-in-service-{accountId}-{flowId}` | grpc-in pod — reads from Kafka |
| ConfigMap | `cdc-soar-light-cm-{accountId}-{flowId}` | soar-light pod configuration |
| StatefulSet | `cdc-soar-light-service-{accountId}-{flowId}` | soar-light pod — runs Python script |

Total: **2 pods, 2 ConfigMaps, 2 StatefulSets** per flow.

### 2.2 Validation Block

`cdc.flow.api.service/pkg/svc/flow_handler_service.go` — `validateC2CService()`:

```go
switch src.Type {
case db.SourceNIOSType, db.SourceIngressType, db.SourceScheduleType:
    return fmt.Errorf("source type %s is not supported for Data Connector in Infoblox Cloud",
        db.SourceTypeToName[src.Type])
}
```

`SOURCE_SCHEDULE` is rejected alongside `SOURCE_NIOS` and `SOURCE_INGRESS`.

### 2.3 On-Prem vs C2C Comparison

| Aspect | On-Prem | C2C |
|--------|---------|-----|
| Deployment | Single soar-light binary, all flows | Per-flow K8s pods |
| Config delivery | JSON file on disk | FLOW_JSON env var in ConfigMap |
| Scheduled support | Yes — internal cron in the binary | Blocked at API validation |
| grpc-in pod | None | Required for event-driven flows |

---

## 3. Proposed Behavior

### 3.1 For Scheduled C2C Flows

| Resource | Name Pattern | Created? |
|----------|-------------|----------|
| ConfigMap | `cdc-grpc-in-cm-{accountId}-{flowId}` | **No** |
| StatefulSet | `cdc-grpc-in-service-{accountId}-{flowId}` | **No** |
| ConfigMap | `cdc-soar-light-cm-{accountId}-{flowId}` | Yes |
| StatefulSet | `cdc-soar-light-service-{accountId}-{flowId}` | Yes |

Total: **1 pod, 1 ConfigMap, 1 StatefulSet** per scheduled flow.

### 3.2 Scheduled Flow Detection Criteria

A flow is classified as scheduled when:

```
len(SourceDataTypes) == 0  AND  ScriptSchedule != ""
```

### 3.3 soar-light: Start the Cron Scheduler in Cloud Mode

The soar-light binary already contains the cron registration logic in `pkg/dapr/subscriber.go` → `runDataFlow()`:

```go
if len(flow.DataTypes) == 0 && flow.Schedule != "" {
    cronId, err := s.o.Manager.ProcessScheduledScript(flow)
    s.o.Config.AddCronID(flow.Id, cronId)
    return &flow, nil
}
```

However, the `robfig/cron` scheduler was **never started** in cloud mode (`cmd/cloud/main.go`). The on-prem entry point (`cmd/onprem/main.go`) calls `cron.Start()`, but the cloud entry point did not. Without `cron.Start()`, the cron library registers jobs but its internal ticker goroutine never fires — so `IScheduler.schedule()` is never called.

**Fix**: Add `cron.Start()` + `defer cron.Stop()` in `cmd/cloud/main.go` before the `ProcessEvent` goroutine.

---

## 4. Scope

### In Scope

| Item | Repository |
|------|-----------|
| Remove `SOURCE_SCHEDULE` from C2C blocked list | `cdc.flow.api.service` |
| Return `nil` InSvc for scheduled flows | `cdc.flow.api.service` |
| Allow `nil` InSvc in `NewCDCFlowHandler()` | `cdc.flow.api.service` |
| Add nil checks in `CreateFlow`, `UpdateFlow`, `DeleteFlow` | `cdc.flow.api.service` |
| Fix sync reconciliation loop for nil InSvc | `cdc.flow.api.service` |
| Fix ConfigMap count expectation in sync | `cdc.flow.api.service` |
| Start cron scheduler in cloud mode | `soar-light` |

### Out of Scope

| Item | Reason |
|------|--------|
| Python driver changes | Already supports `--script-schedule` mode |
| CDC API changes | No API contract changes needed |
| On-prem flow behavior | Unaffected |

---

## 5. Technical Analysis

### 5.1 Key Code Path: soar-light Scheduled Execution

```
cmd/cloud/main.go
  → viper.GetString("flow.json")           // reads FLOW_JSON from ConfigMap env
  → svc.GetCron().Start()                   // CHANGE 7: start cron scheduler
  → daprSub.ProcessEvent(flowJSON)
    → processEvent()
      → json.Unmarshal → FlowEvent
      → validateConfig(fc)                  // reject on-prem flows (has hosts/services)
      → validateDestinations(fc.Destinations)
      → runDataFlow(fc)
        → getParsedAndEncodedFlowConfig()
        → if DataTypes==0 && Schedule!="" → ProcessScheduledScript(flow)
          → creates Python venv
          → starts cron job
          → Python calls IScheduler.schedule() on each cron tick
```

### 5.2 Key Code Path: cdc.flow.api.service Flow Handler

```
FlowEvent received via Dapr PubSub
  → validateC2CService()                   // CHANGE 1: allow SOURCE_SCHEDULE
  → getSrcSvcConf(flowEvent)               // CHANGE 2: return nil for scheduled
  → NewCDCFlowHandler(flowEvent)           // CHANGE 3: accept nil InSvc
    → CDCFlowHandler{InSvc: nil, OutSvc: soarLightSvc}
  → fh.CreateFlow()                        // CHANGE 4: skip nil InSvc operations
    → OutSvc.CreateOrUpdateConfigMap()
    → OutSvc.CreateStatefulSet()
```

### 5.3 Sync Reconciliation Loop

`syncCDCFlows()` runs periodically to reconcile in-cluster state:

```
syncCDCFlows()
  → for each active flow handler:
    → syncConfigMaps()                     // CHANGE 5: handle nil InSvc
    → syncStatefulSets()                   // CHANGE 5: handle nil InSvc
    → check ConfigMap count                // CHANGE 6: expect 1 CM for scheduled
```

---

## 6. Implementation Details

### Change 1: Remove `SOURCE_SCHEDULE` from blocked list

**File**: `cdc.flow.api.service/pkg/svc/flow_handler_service.go`

```diff
 switch src.Type {
-case db.SourceNIOSType, db.SourceIngressType, db.SourceScheduleType:
+case db.SourceNIOSType, db.SourceIngressType:
     return fmt.Errorf("source type %s is not supported for Data Connector in Infoblox Cloud",
         db.SourceTypeToName[src.Type])
 }
```

---

### Change 2: Return `nil` InSvc for scheduled sources

**File**: `cdc.flow.api.service/pkg/svc/utils.go` — `getSrcSvcConf()`

```diff
 func getSrcSvcConf(config *dapr.FlowEvent) cdcSvc {
+    if len(config.Flow.SourceDataTypes) == 0 && config.Flow.ScriptSchedule != "" {
+        return nil
+    }
     return NewGrpcInSvcCli(config)
 }
```

---

### Change 3: Allow `nil` InSvc in `NewCDCFlowHandler()`

**File**: `cdc.flow.api.service/pkg/svc/flow_handler.go`

```diff
 inSvc := getSrcSvcConf(flowEvent)
-if inSvc == nil {
+if inSvc == nil && !isScheduledFlow(flowEvent) {
     return nil, fmt.Errorf("invalid source for cloud flow, flow: %v", flowEvent.Flow.Id)
 }
```

New helper function:

```go
func isScheduledFlow(fe *dapr.FlowEvent) bool {
    return len(fe.Flow.SourceDataTypes) == 0 && fe.Flow.ScriptSchedule != ""
}
```

---

### Change 4: Nil-safe InSvc in `CreateFlow()`, `UpdateFlow()`, `DeleteFlow()`

**File**: `cdc.flow.api.service/pkg/svc/flow_handler.go`

All three methods wrapped InSvc calls:

```go
if fh.InSvc != nil {
    if err := fh.InSvc.CreateOrUpdateConfigMap(); err != nil { return err }
    if err := fh.InSvc.CreateStatefulSet(); err != nil { return err }
}
// OutSvc always executes
if err := fh.OutSvc.CreateOrUpdateConfigMap(); err != nil { return err }
if err := fh.OutSvc.CreateStatefulSet(); err != nil { return err }
```

Same pattern applied to `UpdateFlow()` and `DeleteFlow()`.

---

### Change 5: Fix sync functions for nil InSvc

**File**: `cdc.flow.api.service/pkg/svc/utils.go`

**`syncConfigMaps()`**: Declare `var inSvcCM *corev1.ConfigMap`, populate only if `flh.InSvc != nil`. Add nil check when matching ConfigMap names.

**`syncStatefulSets()`**: Remove `flh.InSvc == nil` from the error condition. Conditionally prepare and sync InSvc StatefulSet only when non-nil.

---

### Change 6: Fix ConfigMap count expectation in `syncCDCFlows()`

**File**: `cdc.flow.api.service/pkg/svc/utils.go`

```diff
-if len(cms) != 2 {
-    logrus.Warnf("Unexpected number of ConfigMaps (%d) for flow ID %d, expected 2, cms: %v.",
-        len(cms), flowId, names)
+expectedCmCount := 2
+if flh.InSvc == nil {
+    expectedCmCount = 1
+}
+if len(cms) != expectedCmCount {
+    logrus.Warnf("Unexpected number of ConfigMaps (%d) for flow ID %d, expected %d, cms: %v.",
+        len(cms), flowId, expectedCmCount, names)
 }
```

---

### Change 7: Start cron scheduler in cloud mode

**File**: `soar-light/cmd/cloud/main.go`

The on-prem entry point (`cmd/onprem/main.go`, ~line 71) calls `svc.GetCron().Start()`, but the cloud entry point was missing this call entirely. Without it, `robfig/cron` registers jobs via `ProcessScheduledScript()` but the internal ticker goroutine never starts — so `IScheduler.schedule()` is never invoked.

```diff
  flowJSON := viper.GetString("flow.json")
  logger.Debugf("flowJSON config: %v", flowJSON)

+ // Start the cron scheduler so scheduled flows (SOURCE_SCHEDULE) can fire.
+ cronScheduler := svc.GetCron()
+ cronScheduler.Start()
+ defer cronScheduler.Stop()
+
  go func() {
      if err = daprSub.ProcessEvent(flowJSON); err != nil {
          doneC <- err
      }
  }()
```

---

## 7. Kubernetes Resource Comparison

### Event-Driven Flow (unchanged)

```
$ kubectl get all -n cdc-data-flow | grep {flowId}
pod/cdc-grpc-in-service-{acctId}-{flowId}-0          1/1   Running
pod/cdc-soar-light-service-{acctId}-{flowId}-0       1/1   Running
configmap/cdc-grpc-in-cm-{acctId}-{flowId}
configmap/cdc-soar-light-cm-{acctId}-{flowId}
statefulset.apps/cdc-grpc-in-service-{acctId}-{flowId}
statefulset.apps/cdc-soar-light-service-{acctId}-{flowId}
```

### Scheduled Flow (after changes)

```
$ kubectl get all -n cdc-data-flow | grep {flowId}
pod/cdc-soar-light-service-{acctId}-{flowId}-0       1/1   Running
configmap/cdc-soar-light-cm-{acctId}-{flowId}
statefulset.apps/cdc-soar-light-service-{acctId}-{flowId}
```

### Per-Flow Resource Savings

| Resource | Event Flow | Scheduled Flow | Saved |
|----------|-----------|----------------|-------|
| Pods | 2 | 1 | 1 |
| StatefulSets | 2 | 1 | 1 |
| ConfigMaps | 2 | 1 | 1 |
| Memory | ~200Mi | ~100Mi | ~100Mi |
| CPU | ~60m | ~30m | ~30m |
| Kafka connections | 1 | 0 | 1 |

---

## 8. End-to-End Flow

### 8.1 Flow Creation

```
1. Customer creates flow via CDC API:
   - source_type: SOURCE_SCHEDULE
   - source_data_types: []
   - script_schedule: "*/5 * * * *"
   - destinations: [{ type: DESTINATION_APPLICATION, application: { type: PYTHON_SCRIPT, ... } }]

2. cdc.flow.api.service:
   - validateC2CService() → PASSES (SOURCE_SCHEDULE no longer blocked)
   - getSrcSvcConf() → returns nil (scheduled flow detected)
   - NewCDCFlowHandler() → CDCFlowHandler{InSvc: nil, OutSvc: soarLightSvc}
   - CreateFlow() → skips InSvc, creates OutSvc ConfigMap + StatefulSet

3. Kubernetes creates:
   - ConfigMap: cdc-soar-light-cm-{acctId}-{flowId}  (contains FLOW_JSON)
   - StatefulSet: cdc-soar-light-service-{acctId}-{flowId}  (1 replica)

4. soar-light pod starts:
   - Reads FLOW_JSON from env var
   - cron.Start() fires the robfig/cron ticker goroutine (Change 7)
   - processEvent() → validateDestinations() → runDataFlow()
   - Detects: DataTypes=0, Schedule="*/5 * * * *"
   - Calls ProcessScheduledScript() → creates venv → registers cron job
   - Cron ticker invokes IScheduler.schedule() every 5 minutes
```

### 8.2 Flow Deletion

```
1. Customer deletes flow via CDC API
2. cdc.flow.api.service:
   - DeleteFlow() → skips InSvc (nil), deletes OutSvc ConfigMap + StatefulSet
3. Kubernetes removes the soar-light pod
```

### 8.3 Sync Reconciliation

```
1. syncCDCFlows() runs periodically
2. For scheduled flows:
   - Expects 1 ConfigMap (not 2)
   - Skips InSvc ConfigMap/StatefulSet reconciliation
   - Reconciles OutSvc ConfigMap + StatefulSet normally
```

---

## 9. Impact Summary

| Component | Impact | Changes |
|-----------|--------|---------|
| `cdc.flow.api.service/pkg/svc/flow_handler_service.go` | Modified | Remove `SourceScheduleType` from blocked list |
| `cdc.flow.api.service/pkg/svc/flow_handler.go` | Modified | `isScheduledFlow()` helper; nil InSvc handling in constructor + CRUD |
| `cdc.flow.api.service/pkg/svc/utils.go` | Modified | `getSrcSvcConf()` returns nil; sync functions handle nil InSvc |
| `soar-light/cmd/cloud/main.go` | Modified | Add `cron.Start()` so scheduled jobs fire in cloud mode |
| `cdc.grpc-in/*` | None | Not involved in scheduled flows |
| CDC API contract | None | No API changes |
| On-prem flows | None | Unaffected |
| Existing event-driven C2C flows | None | Behavior unchanged |

---

## 10. Test Validation

### 10.1 Build Verification

```
$ cd cdc.flow.api.service && go build ./pkg/svc/
# Clean — no errors

$ cd soar-light && go build ./cmd/cloud/
# Clean — no errors
```

### 10.2 Unit Tests

```
$ go test ./pkg/svc/ -run "TestNewFlowConfig|Test_extractFlowId|Test_getStsName|Test_getCmName|Test_mergeJson"
# All PASS
```

### 10.3 Live Environment Verification

Flow 3650 created with `SOURCE_SCHEDULE` in the dev cluster:

```
$ kubectl get all -n cdc-data-flow | grep 3650
pod/cdc-soar-light-service-3006869-3650-0       1/1   Running
configmap/cdc-soar-light-cm-3006869-3650
statefulset.apps/cdc-soar-light-service-3006869-3650
```

Result: **1 pod, 1 ConfigMap, 1 StatefulSet** — no grpc-in resources created.

---

## 11. Resolved Issues

### 11.1 soar-light: "destination config is empty"

**Status**: Resolved

The deployed soar-light Docker image was running an older code version (not `release/v0.4.3`). The error message format differed from the source code:
- Deployed: `level=debug msg="Skip further event processing, destination config is empty"`
- Source (`release/v0.4.3`): `level=warn msg="Skipping event processing due to invalid destination: ..."`

**Resolution**: Redeployed with the correct `release/v0.4.3` base image. Flow creation, cron registration, and health monitor all started working.

### 11.2 Cron `schedule()` never fires in cloud mode

**Status**: Resolved (Change 7)

After fixing issue 11.1, the health monitor ran every 5 minutes but `IScheduler.schedule()` was never called. Root cause: `cron.Start()` was present in `cmd/onprem/main.go` but **missing from `cmd/cloud/main.go`**. Without it, `robfig/cron` registered jobs but never started its internal ticker goroutine.

**Resolution**: Added `svc.GetCron().Start()` + `defer cronScheduler.Stop()` in `cmd/cloud/main.go` (Change 7 above).

### 11.3 Python Script Interface

Scheduled flows require only `IScheduler` — the `IEventHandler` interface is not used. The soar-light driver (`infoblox_driver.py`) detects the correct class via the `--script-schedule` flag automatically.

---
