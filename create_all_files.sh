#!/bin/bash

# This script creates all remaining project files

cd /home/claude/sentinel-remediation-engine

# Create .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
.venv/
*.egg-info/
dist/
build/

# Terraform
*.tfstate
*.tfstate.*
.terraform/
*.tfvars
!*.tfvars.example
.terraform.lock.hcl

# IDE
.vscode/
.idea/
*.swp
*.swo

# Environment
.env
*.env.local

# Azure
local.settings.json
*.publish.settings

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
EOF

# Create environment-specific tfvars
mkdir -p terraform/environments/{dev,staging,prod}

cat > terraform/environments/dev/terraform.tfvars << 'EOF'
environment         = "dev"
location           = "eastus"
resource_group_name = "sentinel-remediation-dev-rg"

# Sentinel
sentinel_workspace_name = "sentinel-dev"
sentinel_retention_days = 30
sentinel_daily_quota_gb = 5

# Functions
functions_app_name = "remediation-func-dev"
functions_runtime  = "python"
functions_runtime_version = "3.11"

# Networking
vnet_address_space            = ["10.0.0.0/16"]
function_subnet_prefix         = "10.0.1.0/24"
private_endpoint_subnet_prefix = "10.0.2.0/24"
enable_private_endpoints       = false
enable_ddos_protection         = false

# Features
enable_auto_remediation     = false  # Dry-run mode in dev
enable_predictive_detection = true
threat_score_threshold      = 50

# Notifications
security_email = "security-dev@company.com"
EOF

cat > terraform/environments/prod/terraform.tfvars << 'EOF'
environment         = "prod"
location           = "eastus"
resource_group_name = "sentinel-remediation-prod-rg"

# Sentinel
sentinel_workspace_name = "sentinel-prod"
sentinel_retention_days = 90
sentinel_daily_quota_gb = -1

# Functions
functions_app_name = "remediation-func-prod"
functions_runtime  = "python"
functions_runtime_version = "3.11"

# Networking
vnet_address_space            = ["10.0.0.0/16"]
function_subnet_prefix         = "10.0.1.0/24"
private_endpoint_subnet_prefix = "10.0.2.0/24"
enable_private_endpoints       = true
enable_ddos_protection         = true

# Features
enable_auto_remediation     = true
enable_predictive_detection = true
threat_score_threshold      = 70

# Notifications
security_email = "security-prod@company.com"
EOF

# Create backend config
cat > terraform/backend.hcl << 'EOF'
resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstate<unique>"
container_name       = "tfstate"
key                  = "sentinel-remediation.tfstate"
EOF

echo "All configuration files created successfully!"
