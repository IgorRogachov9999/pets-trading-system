terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # All values are supplied via -backend-config flags in CI or a local .hcl file.
    #
    # CI (GitHub Actions): terraform init -backend-config flags in workflow YAML.
    # Local dev: copy terraform/backend-dev.hcl.example → terraform/backend-dev.hcl,
    #            fill in values, then run:
    #              terraform init -backend-config=backend-dev.hcl
    #
    # The only hard-coded default is encrypt=true — never disable this.
    encrypt = true
  }
}
