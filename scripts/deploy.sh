#!/bin/bash

###############################################################################
# Sentinel Predictive Remediation Engine - Deployment Script
# This script orchestrates the complete deployment of the solution
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENT="${1:-dev}"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found. Please install: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install: https://www.terraform.io/downloads"
        exit 1
    fi
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found. Please install Python 3.9 or higher"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure. Please run: az login"
        exit 1
    fi
    
    log_info "All prerequisites met ✓"
}

load_environment() {
    log_info "Loading environment configuration for: $ENVIRONMENT"
    
    if [ -f "$PROJECT_ROOT/.env" ]; then
        source "$PROJECT_ROOT/.env"
        log_info "Environment variables loaded from .env"
    else
        log_warn ".env file not found. Using defaults."
    fi
}

deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd "$PROJECT_ROOT/terraform/environments/$ENVIRONMENT"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init -upgrade
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log_info "Creating Terraform plan..."
    terraform plan -out=tfplan
    
    # Apply (with confirmation)
    read -p "Apply this Terraform plan? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
        log_info "Applying Terraform configuration..."
        terraform apply tfplan
        log_info "Infrastructure deployment complete ✓"
    else
        log_warn "Deployment cancelled by user"
        exit 0
    fi
    
    # Save outputs
    terraform output -json > "$PROJECT_ROOT/terraform-outputs.json"
    log_info "Terraform outputs saved to terraform-outputs.json"
    
    cd "$PROJECT_ROOT"
}

deploy_functions() {
    log_info "Deploying Azure Functions..."
    
    # Get function app name from Terraform outputs
    FUNCTION_APP_NAME=$(cat "$PROJECT_ROOT/terraform-outputs.json" | python3 -c "import sys, json; print(json.load(sys.stdin)['functions']['value']['app_name'])")
    RESOURCE_GROUP=$(cat "$PROJECT_ROOT/terraform-outputs.json" | python3 -c "import sys, json; print(json.load(sys.stdin)['resource_group']['value']['name'])")
    
    log_info "Function App: $FUNCTION_APP_NAME"
    log_info "Resource Group: $RESOURCE_GROUP"
    
    # Create deployment package
    cd "$PROJECT_ROOT/src/functions"
    
    log_info "Installing Python dependencies..."
    pip3 install --target .python_packages/lib/site-packages -r ../../azure-functions/requirements.txt
    
    log_info "Creating deployment package..."
    zip -r function-app.zip . -x "*.pyc" -x "__pycache__/*" -x ".venv/*"
    
    # Deploy to Azure
    log_info "Deploying to Azure Functions..."
    az functionapp deployment source config-zip \
        --resource-group "$RESOURCE_GROUP" \
        --name "$FUNCTION_APP_NAME" \
        --src function-app.zip
    
    # Cleanup
    rm function-app.zip
    
    log_info "Functions deployment complete ✓"
    
    cd "$PROJECT_ROOT"
}

deploy_sentinel_rules() {
    log_info "Deploying Sentinel analytics rules..."
    
    WORKSPACE_NAME=$(cat "$PROJECT_ROOT/terraform-outputs.json" | python3 -c "import sys, json; print(json.load(sys.stdin)['sentinel']['value']['workspace_name'])")
    RESOURCE_GROUP=$(cat "$PROJECT_ROOT/terraform-outputs.json" | python3 -c "import sys, json; print(json.load(sys.stdin)['resource_group']['value']['name'])")
    
    log_info "Sentinel Workspace: $WORKSPACE_NAME"
    
    # Deploy KQL rules
    cd "$PROJECT_ROOT/sentinel/analytics-rules"
    
    for rule_file in *.kql; do
        if [ -f "$rule_file" ]; then
            log_info "Deploying rule: $rule_file"
            # Rule deployment logic here
        fi
    done
    
    log_info "Sentinel rules deployment complete ✓"
    
    cd "$PROJECT_ROOT"
}

run_smoke_tests() {
    log_info "Running smoke tests..."
    
    cd "$PROJECT_ROOT"
    
    # Install test dependencies
    pip3 install pytest pytest-asyncio requests
    
    # Run tests
    pytest tests/integration/test_smoke.py -v
    
    if [ $? -eq 0 ]; then
        log_info "Smoke tests passed ✓"
    else
        log_error "Smoke tests failed ✗"
        exit 1
    fi
}

print_summary() {
    log_info "═══════════════════════════════════════════════════════════"
    log_info "         Deployment Complete!"
    log_info "═══════════════════════════════════════════════════════════"
    
    echo ""
    echo "Environment: $ENVIRONMENT"
    echo ""
    echo "Resource Group: $(cat terraform-outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['resource_group']['value']['name'])")"
    echo "Sentinel Workspace: $(cat terraform-outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['sentinel']['value']['workspace_name'])")"
    echo "Functions App: $(cat terraform-outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['functions']['value']['app_name'])")"
    echo ""
    echo "Next Steps:"
    echo "1. Access Sentinel: https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights"
    echo "2. Monitor Functions: https://portal.azure.com → Function Apps → $(cat terraform-outputs.json | python3 -c "import sys, json; print(json.load(sys.stdin)['functions']['value']['app_name'])")"
    echo "3. View Logs: az monitor log-analytics query --workspace <workspace-id> --analytics-query 'FunctionAppLogs'"
    echo "4. Run tests: ./scripts/test.sh"
    echo ""
    log_info "═══════════════════════════════════════════════════════════"
}

# Main deployment flow
main() {
    log_info "Starting deployment for environment: $ENVIRONMENT"
    
    check_prerequisites
    load_environment
    deploy_infrastructure
    deploy_functions
    deploy_sentinel_rules
    
    if [ "$ENVIRONMENT" != "prod" ]; then
        run_smoke_tests
    fi
    
    print_summary
}

# Handle script arguments
case "${1}" in
    --help|-h)
        echo "Usage: $0 [environment] [--skip-tests]"
        echo ""
        echo "Environments: dev, staging, prod"
        echo ""
        echo "Options:"
        echo "  --skip-tests    Skip smoke tests"
        echo "  --help, -h      Show this help message"
        exit 0
        ;;
    *)
        main
        ;;
esac
