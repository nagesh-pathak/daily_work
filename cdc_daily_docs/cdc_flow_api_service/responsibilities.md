# cdc.flow.api.service — Responsibilities


### Added 2026-05-20 17:01

- Expose APIs to manage flow / tenant / config state.
- Persist state to the backing store with versioning.
- Publish change events so data-plane components reload.
- Validate inputs against schema (CRDs / OpenAPI).
- Audit who changed what and when.
