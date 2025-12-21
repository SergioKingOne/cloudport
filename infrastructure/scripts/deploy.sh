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

usage() {
    echo "Usage: $0 [primary|dr|all]"
    echo ""
    echo "Options:"
    echo "  primary   Deploy primary environment only"
    echo "  dr        Deploy DR environment only"
    echo "  all       Deploy both environments (primary first)"
    exit 1
}

deploy_primary() {
    echo -e "${BLUE}Deploying Primary Environment (us-east-1)...${NC}"
    cd "$INFRA_DIR/environments/primary"
    terraform apply -auto-approve
    echo -e "${GREEN}Primary environment deployed!${NC}"
}

deploy_dr() {
    echo -e "${BLUE}Deploying DR Environment (us-west-2)...${NC}"

    # Get outputs from primary for DR configuration
    cd "$INFRA_DIR/environments/primary"

    if terraform output alb_dns_name &> /dev/null; then
        PRIMARY_ALB_DNS=$(terraform output -raw alb_dns_name)
        PRIMARY_ALB_ZONE=$(terraform output -raw alb_zone_id)
        PRIMARY_ALB_ARN=$(terraform output -raw alb_arn)
        GLOBAL_CLUSTER_ID=$(terraform output -raw aurora_global_cluster_id 2>/dev/null || echo "")

        cd "$INFRA_DIR/environments/dr"

        terraform apply -auto-approve \
            -var="primary_alb_dns_name=${PRIMARY_ALB_DNS}" \
            -var="primary_alb_zone_id=${PRIMARY_ALB_ZONE}" \
            -var="primary_alb_arn=${PRIMARY_ALB_ARN}" \
            -var="global_cluster_id=${GLOBAL_CLUSTER_ID}"
    else
        echo -e "${YELLOW}Primary environment not deployed. Deploying DR with defaults...${NC}"
        cd "$INFRA_DIR/environments/dr"
        terraform apply -auto-approve
    fi

    echo -e "${GREEN}DR environment deployed!${NC}"
}

case "${1:-all}" in
    primary)
        deploy_primary
        ;;
    dr)
        deploy_dr
        ;;
    all)
        deploy_primary
        echo ""
        deploy_dr
        echo -e "\n${GREEN}All environments deployed successfully!${NC}"
        ;;
    *)
        usage
        ;;
esac
