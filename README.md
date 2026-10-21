# Azure ML basic MLOps: NYC Taxi fare

Predicts a taxi trip's price. The model is simple on purpose: the point is the MLOps around it.
**Everything you need to present and understand it: [docs/PRESENTER_GUIDE.md](docs/PRESENTER_GUIDE.md).**

## Folders
| Folder | What |
|---|---|
| `infra/platform/` | Terraform: workspaces, cluster, data asset, identities, permissions, GitHub settings |
| `aml/` | Azure ML YAML: environment, 4 components, 2 pipelines, endpoint |
| `src/` | Python: `taxi_aml/model.py` (logic, unit-tested) + `jobs/` (pipeline steps) |
| `scripts/` | What GitHub runs: `train.sh`, `deploy.sh`, `smoke_test.sh`, `monitor.sh` |
| `.github/workflows/` | `ci.yml` (PR), `cd.yml` (main), `rollback.yml` (manual) |
| `tests/` | pytest |

## Quick start
```bash
az login
gh repo create azureml-taxi-mlops --public --source . --push
cd infra/platform && cp terraform.tfvars.example terraform.tfvars
GITHUB_TOKEN=$(gh auth token) terraform init && GITHUB_TOKEN=$(gh auth token) terraform apply
```
Then open a pull request, and GitHub does the rest (see the guide).

## Sources
- [Azure/mlops-v2](https://github.com/Azure/mlops-v2) and [Azure/mlops-v2-cv-demo](https://github.com/Azure/mlops-v2-cv-demo): CLI v2 + GitHub Actions + Terraform layout for dev/prod
- [Azure/mlops-starter-sklearn](https://github.com/Azure/mlops-starter-sklearn): small sklearn MLOps sample with GitHub Actions
- This repo's `../Azure_ML` and `../foundry-skills` projects: Terraform patterns and the GitHub OIDC numeric-ID subject
- Fact checks only: [managed online endpoint VM SKUs](https://learn.microsoft.com/azure/machine-learning/reference-managed-online-endpoints-vm-sku-list) (DS1_v2 allowed, 20% quota reserve)
