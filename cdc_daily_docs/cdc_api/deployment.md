# cdc.api — Deployment notes


### 2026-05-07 11:15

- Deployed via Helm chart in the CDC umbrella release.
- Runs as a Kubernetes Deployment (stateless) with N replicas.
- HorizontalPodAutoscaler typically driven by CPU + custom Kafka-lag metric.
- ConfigMap holds non-secret runtime config; Secret holds destination creds.
- PodDisruptionBudget recommended (`minAvailable: 1`) for egress paths.
- Liveness on `/healthz`, readiness on `/ready`.
