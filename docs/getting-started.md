# Getting Started with Sentinel Predictive Remediation Engine

This guide will walk you through deploying the Sentinel Predictive Remediation Engine from scratch.

## Prerequisites

### Required Tools

1. **Azure CLI** (>= 2.50.0)
   ```bash
   # Install
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Verify
   az --version
   ```

2. **Terraform** (>= 1.6.0)
   ```bash
   # Install
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   
   # Verify
   terraform --version
   ```

3. **Python** (>= 3.11)
   ```bash
   # Install
   sudo apt install python3.11 python3-pip
   
   # Verify
   python3 --version
   ```

### Azure Permissions

You need the following Azure RBAC roles:
- **Contributor** - To create resources
- **User Access Administrator** - To assign roles
- **Microsoft Sentinel Contributor** - To configure Sentinel

## Step-by-Step Deployment

### Step 1: Clone and Configure

```bash
# Clone repository
git clone <your-repo-url>
cd sentinel-remediation-engine

# Copy environment template
cp .env.example .env

# Edit .env with your values
nano .env
```

Required environment variables:
```bash
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_TENANT_ID=your-tenant-id
RESOURCE_GROUP=sentinel-remediation-dev-rg
LOCATION=eastus
```

### Step 2: Authenticate with Azure

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "<your-subscription-id>"

# Verify
az account show
```

### Step 3: Initialize Terraform Backend (Optional but Recommended)

```bash
# Create storage account for Terraform state
az group create --name terraform-state-rg --location eastus

az storage account create \
  --name tfstate$RANDOM \
  --resource-group terraform-state-rg \
  --location eastus \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name <storage-account-name>

# Update terraform/backend.hcl with your values
```

### Step 4: Review Terraform Configuration

```bash
cd terraform/environments/dev

# Review variables
cat terraform.tfvars

# Customize as needed
nano terraform.tfvars
```

Key variables to configure:
- `environment`: dev/staging/prod
- `location`: Azure region
- `sentinel_workspace_name`: Unique workspace name
- `functions_app_name`: Unique function app name
- `security_email`: Your email for alerts

### Step 5: Deploy Infrastructure

```bash
# From project root
./scripts/deploy.sh dev
```

This will:
1.  Check prerequisites
2.  Initialize Terraform
3.  Create infrastructure plan
4.  Deploy all resources
5.  Deploy function code
6.  Import Sentinel rules
7.  Run smoke tests

**Deployment time**: Approximately 15-20 minutes

### Step 6: Verify Deployment

```bash
# Check resource group
az group show --name sentinel-remediation-dev-rg

# List deployed resources
az resource list \
  --resource-group sentinel-remediation-dev-rg \
  --output table

# Test function endpoint
FUNCTION_URL=$(az functionapp show \
  --name remediation-func-dev \
  --resource-group sentinel-remediation-dev-rg \
  --query defaultHostName -o tsv)

curl https://$FUNCTION_URL/api/health
```

### Step 7: Access Sentinel

1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Sentinel**
3. Select your workspace: `sentinel-dev`
4. Explore:
   - **Analytics** → See deployed rules
   - **Automation** → See automation rules
   - **Workbooks** → View dashboards

### Step 8: Configure DevOps Integration (Optional)

```bash
# Set DevOps PAT in Key Vault
az keyvault secret set \
  --vault-name <your-key-vault> \
  --name devops-pat \
  --value "<your-pat-token>"

# Update function app settings
az functionapp config appsettings set \
  --name remediation-func-dev \
  --resource-group sentinel-remediation-dev-rg \
  --settings DEVOPS_ORG_URL="https://dev.azure.com/yourorg" \
              DEVOPS_PROJECT="SecurityOps"
```

## Testing Your Deployment

### Run Smoke Tests

```bash
# From project root
./scripts/test.sh --smoke-test
```

### Trigger a Test Alert

```bash
# Create test failed login
python3 scripts/generate-test-event.py --scenario failed-login

# Check Sentinel for alert (wait 5-15 minutes)
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "SecurityAlert | where TimeGenerated > ago(30m)" \
  --output table
```

### View Function Logs

```bash
# Stream logs
az functionapp logs tail \
  --name remediation-func-dev \
  --resource-group sentinel-remediation-dev-rg

# Query logs
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "FunctionAppLogs | where TimeGenerated > ago(1h) | order by TimeGenerated desc" \
  --output table
```

## Common Issues & Solutions

### Issue: Terraform backend initialization fails

**Solution**:
```bash
# Remove backend configuration temporarily
cd terraform/environments/dev
terraform init -migrate-state
```

### Issue: Function deployment fails

**Solution**:
```bash
# Redeploy functions manually
cd src/functions
zip -r function-app.zip .
az functionapp deployment source config-zip \
  --resource-group sentinel-remediation-dev-rg \
  --name remediation-func-dev \
  --src function-app.zip
```

### Issue: Sentinel rules not appearing

**Solution**:
```bash
# Check Sentinel solution is enabled
az monitor log-analytics solution show \
  --resource-group sentinel-remediation-dev-rg \
  --workspace-name sentinel-dev \
  --name SecurityInsights
```

## Next Steps

1. **Configure Data Connectors**
   - Azure AD
   - Azure Activity
   - Microsoft Defender for Cloud

2. **Customize Analytics Rules**
   - Edit KQL queries in `sentinel/analytics-rules/`
   - Adjust threat score thresholds
   - Add custom detection logic

3. **Set Up Notifications**
   - Configure Teams webhook
   - Set up email alerts
   - Integrate with PagerDuty

4. **Enable DevOps Integration**
   - Connect to Azure DevOps
   - Set up security gates in pipelines
   - Configure automatic ticket creation

5. **Deploy to Staging/Production**
   ```bash
   ./scripts/deploy.sh staging
   ./scripts/deploy.sh prod
   ```

## Architecture Overview

```
┌─────────────────┐
│    Sentinel     │  ← Ingests logs, runs analytics
│   (Detection)   │
└────────┬────────┘
         │ Triggers
         ▼
┌─────────────────┐
│   Logic Apps    │  ← Orchestrates workflow
│ (Orchestration) │
└────────┬────────┘
         │ Calls
         ▼
┌─────────────────┐
│Azure Functions  │  ← Executes remediation
│  (Remediation)  │
└────────┬────────┘
         │ Updates
         ▼
┌─────────────────┐
│ Azure DevOps    │  ← Creates tickets, PRs
│  (Integration)  │
└─────────────────┘
```

## Cost Estimation

**Monthly costs for dev environment**:
- Sentinel + Log Analytics: ~$100-200
- Azure Functions (EP1): ~$50-100
- Storage: ~$10-20
- Networking: ~$10-20
- **Total**: ~$170-340/month

**Production costs** will be higher based on:
- Log ingestion volume
- Function execution frequency
- Data retention period

## Support

- **Documentation**: See `/docs` folder
- **Issues**: GitHub Issues
- **Email**: security-devops@company.com

## Additional Resources

- [Terraform Modules README](../terraform/modules/README.md)
- [Function Development Guide](function-development.md)
- [Sentinel Rule Guide](sentinel-rule-guide.md)
- [Troubleshooting Guide](troubleshooting.md)
