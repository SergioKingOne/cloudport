#!/bin/bash
set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}CloudPort Infrastructure Initialization${NC}"
echo "========================================"

# Check prerequisites
echo -e "\n${BLUE}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Terraform is not installed. Please install Terraform >= 1.5.0${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}AWS CLI is not installed. Please install AWS CLI${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}AWS credentials not configured. Please run 'aws configure'${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

echo -e "${GREEN}AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}AWS Region: ${REGION}${NC}"

# Initialize primary environment
echo -e "\n${BLUE}Initializing Primary Environment (us-east-1)...${NC}"
cd "$INFRA_DIR/environments/primary"
terraform init

# Initialize DR environment
echo -e "\n${BLUE}Initializing DR Environment (us-west-2)...${NC}"
cd "$INFRA_DIR/environments/dr"
terraform init

echo -e "\n${GREEN}Initialization complete!${NC}"
echo -e "\nNext steps:"
echo -e "  1. Review ${YELLOW}infrastructure/environments/primary/terraform.tfvars${NC}"
echo -e "  2. Run ${YELLOW}make plan-primary${NC} to see what will be created"
echo -e "  3. Run ${YELLOW}make deploy-primary${NC} to deploy"
