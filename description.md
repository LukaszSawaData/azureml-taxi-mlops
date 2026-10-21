# Azure ML basic MLOps (NYC Taxi)

The same simple MLOps as `../Databricks`, built on Azure ML.

## Scope
- Data: NYC green taxi, January 2016, from **Azure Open Datasets** (public, ~1.4M trips). Azure ML has no built-in sample catalog, so this is the nearest equivalent.
- Terraform: everything in Azure + GitHub settings.
- Python: scikit-learn + MLflow (Azure ML tracking and model registry).
- Two workspaces: `aml-taxi-dev`, `aml-taxi-prod`. Dev artifacts stay in dev, prod artifacts in prod.
- GitHub Actions with OIDC (no secrets): PR → dev, main → prod with 2 approvals.
- CI checks + training pipeline with data tests.
- Serving: a managed online endpoint per environment + smoke test + rollback.
- Monitoring: quality + drift of the champion, logged to MLflow.
- Fast: dev 3,000 rows, prod 30,000 rows.

## Not included (kept simple)
Managed Feature Store, Azure ML model monitoring (needs Spark), model registry sharing between workspaces.

## Rules
- Region `germanywestcentral`. Quota: 6 vCPU per region, 4 per VM family.
- Run `terraform destroy` after the session: online endpoints cost money even when idle.
