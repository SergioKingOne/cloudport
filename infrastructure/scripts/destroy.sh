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
    echo "  primary   Destroy primary environment only"
    echo "  dr        Destroy DR environment only"
    echo "  all       Destroy both environments (DR first for safety)"
    exit 1
}

confirm() {
    echo -e "${RED}WARNING: This will destroy infrastructure!${NC}"
    read -p "Are you sure? (yes/no): " response
    if [[ "$response" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
}

destroy_dr() {
    echo -e "${RED}Destroying DR Environment (us-west-2)...${NC}"
    cd "$INFRA_DIR/environments/dr"
    terraform destroy -auto-approve
    echo -e "${YELLOW}DR environment destroyed.${NC}"
}

destroy_primary() {
    echo -e "${RED}Destroying Primary Environment (us-east-1)...${NC}"
    cd "$INFRA_DIR/environments/primary"
    terraform destroy -auto-approve
    echo -e "${YELLOW}Primary environment destroyed.${NC}"
}

case "${1:-all}" in
    primary)
        confirm
        destroy_primary
        ;;
    dr)
        confirm
        destroy_dr
        ;;
    all)
        confirm
        echo -e "\n${YELLOW}Destroying DR first (safe order)...${NC}"
        destroy_dr
        echo ""
        destroy_primary
        echo -e "\n${YELLOW}All environments destroyed.${NC}"
        ;;
    *)
        usage
        ;;
esac
