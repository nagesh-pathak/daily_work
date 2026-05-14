# cdc.crds — Troubleshooting


### 2026-05-14 21:02

Common symptoms and first checks:

1. **Pod CrashLoopBackOff** — check env vars, secret mounts, last log line.
2. **High consumer lag** — check broker health, partition assignment, downstream rate.
3. **Auth failures to destination** — rotate / re-mount secret, verify clock skew.
4. **Sudden error spike** — diff recent config push, check upstream schema change.
5. **Memory growth** — check goroutine leak via pprof, in-flight buffer sizes.

Useful commands:
```
kubectl -n cdc logs deploy/cdc.crds --tail=200
kubectl -n cdc describe pod -l app=cdc.crds
kubectl -n cdc top pod -l app=cdc.crds
```
