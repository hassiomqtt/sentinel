# GitHub Actions CI/CD Setup

This document describes how to set up the CI/CD pipelines for the Sentinel Remediation project.

## Workflows Overview

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push/PR to main, develop | Build, test, validate Terraform & Python |
| `cd.yml` | Push to main, manual dispatch | Deploy infrastructure and functions |
| `pr-validation.yml` | Pull requests | Comprehensive PR checks with plan comments |

## Required Secrets

Configure these secrets in your GitHub repository settings (`Settings > Secrets and variables > Actions`):

### Azure Authentication
| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Service Principal App ID |
| `AZURE_CLIENT_SECRET` | Service Principal Secret |
| `AZURE_SUBSCRIPTION_ID` | Target Azure Subscription |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |

### Terraform State Backend
| Secret | Description |
|--------|-------------|
| `TF_STATE_RESOURCE_GROUP` | Resource group containing state storage |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name for tfstate |
| `TF_STATE_CONTAINER` | Blob container name (e.g., `tfstate`) |

## Setup Steps

### 1. Create Azure Service Principal

```bash
# Create SP with Contributor role on your subscription
az ad sp create-for-rbac \
  --name "sentinel-github-actions" \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth

# Grant additional permissions for Sentinel operations
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "Microsoft Sentinel Contributor" \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

### 2. Create Terraform State Backend

```bash
# Create resource group
az group create -n sentinel-tfstate-rg -l eastus

# Create storage account
az storage account create \
  -n sentineltfstate$RANDOM \
  -g sentinel-tfstate-rg \
  -l eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  -n tfstate \
  --account-name <STORAGE_ACCOUNT_NAME>
```

### 3. Configure GitHub Environments

Create environments in `Settings > Environments`:

- **dev** - Development (auto-deploy on push)
- **staging** - Staging (requires approval)
- **prod** - Production (requires approval)

For staging and prod, enable:
- Required reviewers
- Wait timer (optional)
- Deployment branches: `main` only

### 4. Add Secrets to Repository

```bash
# Using GitHub CLI
gh secret set AZURE_CLIENT_ID --body "<value>"
gh secret set AZURE_CLIENT_SECRET --body "<value>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<value>"
gh secret set AZURE_TENANT_ID --body "<value>"
gh secret set TF_STATE_RESOURCE_GROUP --body "sentinel-tfstate-rg"
gh secret set TF_STATE_STORAGE_ACCOUNT --body "<storage-account-name>"
gh secret set TF_STATE_CONTAINER --body "tfstate"
```

## Workflow Details

### CI Workflow (`ci.yml`)

Runs on every push and PR:

1. **Terraform Validate** - Format check, init, validate
2. **Terraform Security** - tfsec + Checkov scans
3. **Python Lint** - Ruff + Black checks
4. **Python Test** - pytest with coverage
5. **KQL Validate** - Basic syntax validation

### CD Workflow (`cd.yml`)

Deployment workflow with manual dispatch:

```yaml
# Manual trigger options:
# - environment: dev | staging | prod
# - action: plan | apply | destroy
```

Auto-deploys to `dev` on push to `main`.

### PR Validation (`pr-validation.yml`)

Enhanced PR experience:
- Detects changed files (terraform/functions/kql)
- Posts Terraform plan as PR comment
- Runs security scans with Trivy
- Provides summary table

## Usage Examples

### Manual Deployment

1. Go to `Actions` > `CD - Deploy Infrastructure`
2. Click `Run workflow`
3. Select environment and action
4. Click `Run workflow`

### Promoting to Production

1. Merge PR to `main`
2. Auto-deploy runs for `dev`
3. Manually trigger `cd.yml` with:
   - environment: `staging`
   - action: `apply`
4. After validation, trigger for `prod`

## Troubleshooting

### Common Issues

**Terraform init fails:**
- Verify TF_STATE_* secrets are correct
- Ensure storage account firewall allows GitHub Actions IPs

**Azure login fails:**
- Check service principal credentials haven't expired
- Verify subscription ID is correct

**Function deployment fails:**
- Ensure function app exists (run terraform first)
- Check function app name matches tfvars

### Debugging

Enable debug logging by setting secret:
```
ACTIONS_STEP_DEBUG=true
```

View detailed logs in the Actions tab.
