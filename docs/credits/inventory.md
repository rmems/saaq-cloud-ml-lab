# Cloud Credit Inventory

This file is the source of truth for free credits available to this repo and their guardrails.

Notes:
- Do not guess expiration dates. If unknown, set `TBD` and update after verifying in the provider/program portal.
- Keep amounts in USD.
- Dates are recorded as `YYYY-MM-DD`.

| Provider | Program / credit type | Amount (USD) | Expiration date | Primary intended uses | Budget caps / guardrails | Notes |
|---|---|---:|---|---|---|---|
| DigitalOcean | Student credits | 205 | 2027-04-28 | Small CPU instances, managed DB trials, reproducible deployments | Default spend cap: $20/experiment; teardown within 24h of completion | Prefer smallest droplet that meets requirements |
| AWS | Student credits | 200 | 2027-03-15 | **Primary training path** — S3 checkpoints, GPU nodes, SageMaker jobs | Default spend cap: $25/experiment; no unmanaged long-lived resources | Use budgets/alerts where available |
| Azure | Student credits | 100 | 2027-02-12 | **Backup managed training** — Azure ML jobs, Blob artifacts | Default spend cap: $15/experiment; teardown same day when possible | Use resource groups per experiment |
| HashiCorp | Student / HCP credits | 500 | 2026-11-10 | HCP Terraform control plane (remote state, runs, policies); optional HCP services | Cap per experiment: $25 unless approved in GitHub issue; prefer free 500 RUM first | Owner confirms **$500 still available** (2026-08-06). TFC API may show `free_standard` — verify billing UI before assuming burn rate |
| Vultr | Account credit | 250 | 2026-05-28 | Completed serverless inference sprint; inactive for near-term execution | Closed out at `$237.31` consumed, `$12.69` expired, `$0.00` owed | Keep records only; do not upload/configure Vultr API keys unless a future issue reactivates provider use |
| IBM Cloud | Cloud credit | 0 (was $200) | 2026-06-28 | **Exhausted** — historical watsonx/COS notes only; not active training path | Do not plan new IBM spend | Operator confirmed **$0 remaining** (2026-08-20); trial window ended 2026-06-28 |
| Oracle Cloud | Free trial | 0 (was $300) | 2026-06-28 | **Exhausted** — document Always Free leftovers vs paid risk only | Do not plan new Oracle promo spend | Operator confirmed **$0 remaining** (2026-08-20); Always Free resources still need monthly paid-risk review |
| GCP | Google AI Pro monthly credit | 10 / month | Monthly | Light experiments only (small inference, minimal storage) | Default spend cap: $10/month; track each run in ledger | Recurs monthly while subscription active |
