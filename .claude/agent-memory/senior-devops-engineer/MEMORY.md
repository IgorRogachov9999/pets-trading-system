# Memory Index

## Files

| File | Type | Description |
|------|------|-------------|
| [project_terraform_bootstrap.md](./project_terraform_bootstrap.md) | project | PTS-24 complete — full 11-module Terraform architecture; remote state still deferred; module inventory and key implementation notes inside |
| [project_terraform_rework.md](./project_terraform_rework.md) | project | PTS-20 complete — ECR shared (no env suffix), IAM distributed to owning modules, log group pattern, dev/demo environments, networking split into 5 files |
| [project_ecr_extraction.md](./project_ecr_extraction.md) | project | ECR extracted to terraform/ecr/ with shared state pts/ecr/terraform.tfstate; per-env terraform/ uses data sources; all pipelines run terraform-ecr job first |
| [project_builds_extraction.md](./project_builds_extraction.md) | project | Builds bucket extracted to terraform/builds/ with shared state pts/builds/terraform.tfstate; per-env terraform/ uses data source; all pipelines run terraform-builds job in parallel with terraform-ecr before terraform-apply |
