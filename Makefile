.PHONY: init deploy deploy-primary deploy-dr destroy destroy-dr destroy-primary status lint cost clean help

# Load .env if exists
-include .env
export

# Configuration
INFRA_DIR := infrastructure
PRIMARY_DIR := $(INFRA_DIR)/environments/primary
DR_DIR := $(INFRA_DIR)/environments/dr

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(BLUE)Enterprise AWS Migration - CloudPort$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

init: ## Initialize Terraform backends for all environments
	@echo "$(BLUE)Initializing Primary Environment (us-east-1)...$(NC)"
	@cd $(PRIMARY_DIR) && terraform init
	@echo "$(BLUE)Initializing DR Environment (us-west-2)...$(NC)"
	@cd $(DR_DIR) && terraform init
	@echo "$(GREEN)All environments initialized!$(NC)"

init-primary: ## Initialize only primary environment
	@echo "$(BLUE)Initializing Primary Environment (us-east-1)...$(NC)"
	@cd $(PRIMARY_DIR) && terraform init

init-dr: ## Initialize only DR environment
	@echo "$(BLUE)Initializing DR Environment (us-west-2)...$(NC)"
	@cd $(DR_DIR) && terraform init

validate: ## Validate Terraform configurations
	@echo "$(BLUE)Validating Primary Environment...$(NC)"
	@cd $(PRIMARY_DIR) && terraform validate
	@echo "$(BLUE)Validating DR Environment...$(NC)"
	@cd $(DR_DIR) && terraform validate
	@echo "$(GREEN)All configurations valid!$(NC)"

lint: ## Format and validate all Terraform files
	@echo "$(BLUE)Formatting Terraform files...$(NC)"
	@terraform fmt -recursive $(INFRA_DIR)
	@$(MAKE) validate
	@echo "$(GREEN)Linting complete!$(NC)"

fmt: ## Format all Terraform files
	@terraform fmt -recursive $(INFRA_DIR)

plan-primary: ## Show execution plan for primary environment
	@echo "$(BLUE)Planning Primary Environment...$(NC)"
	@cd $(PRIMARY_DIR) && terraform plan

plan-dr: ## Show execution plan for DR environment
	@echo "$(BLUE)Planning DR Environment...$(NC)"
	@cd $(DR_DIR) && terraform plan

plan: plan-primary plan-dr ## Show execution plan for all environments

deploy-primary: ## Deploy primary environment (us-east-1)
	@echo "$(BLUE)Deploying Primary Environment (us-east-1)...$(NC)"
	@cd $(PRIMARY_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)Primary environment deployed!$(NC)"

deploy-dr: ## Deploy DR environment (us-west-2)
	@echo "$(BLUE)Deploying DR Environment (us-west-2)...$(NC)"
	@cd $(DR_DIR) && terraform apply -auto-approve
	@echo "$(GREEN)DR environment deployed!$(NC)"

deploy: deploy-primary deploy-dr ## Deploy all environments (primary first, then DR)
	@echo "$(GREEN)All environments deployed successfully!$(NC)"

destroy-dr: ## Destroy DR environment (us-west-2)
	@echo "$(RED)Destroying DR Environment (us-west-2)...$(NC)"
	@cd $(DR_DIR) && terraform destroy -auto-approve
	@echo "$(YELLOW)DR environment destroyed.$(NC)"

destroy-primary: ## Destroy primary environment (us-east-1)
	@echo "$(RED)Destroying Primary Environment (us-east-1)...$(NC)"
	@cd $(PRIMARY_DIR) && terraform destroy -auto-approve
	@echo "$(YELLOW)Primary environment destroyed.$(NC)"

destroy: destroy-dr destroy-primary ## Destroy all environments (DR first, then primary - safe order)
	@echo "$(YELLOW)All environments destroyed.$(NC)"

status: ## Show current state of all environments
	@echo "$(BLUE)Primary Environment Status:$(NC)"
	@cd $(PRIMARY_DIR) && terraform show -no-color 2>/dev/null | head -50 || echo "No state found"
	@echo ""
	@echo "$(BLUE)DR Environment Status:$(NC)"
	@cd $(DR_DIR) && terraform show -no-color 2>/dev/null | head -50 || echo "No state found"

output-primary: ## Show outputs from primary environment
	@cd $(PRIMARY_DIR) && terraform output

output-dr: ## Show outputs from DR environment
	@cd $(DR_DIR) && terraform output

output: output-primary output-dr ## Show outputs from all environments

cost: ## Estimate costs using infracost (requires infracost CLI)
	@echo "$(BLUE)Estimating costs...$(NC)"
	@command -v infracost >/dev/null 2>&1 || { echo "$(RED)infracost not installed. Run: brew install infracost$(NC)"; exit 1; }
	@infracost breakdown --path $(PRIMARY_DIR)
	@infracost breakdown --path $(DR_DIR)

clean: ## Clean up Terraform cache and lock files
	@echo "$(YELLOW)Cleaning up Terraform files...$(NC)"
	@find $(INFRA_DIR) -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find $(INFRA_DIR) -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@find $(INFRA_DIR) -type f -name "*.tfstate*" -delete 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete!$(NC)"

graph: ## Generate dependency graph (requires graphviz)
	@echo "$(BLUE)Generating dependency graph...$(NC)"
	@cd $(PRIMARY_DIR) && terraform graph | dot -Tpng > ../../../architecture.png
	@echo "$(GREEN)Graph saved to architecture.png$(NC)"

docs: ## Generate documentation using terraform-docs
	@echo "$(BLUE)Generating documentation...$(NC)"
	@for dir in $(INFRA_DIR)/modules/*/; do \
		echo "Processing $$dir..."; \
		terraform-docs markdown table "$$dir" > "$$dir/README.md" 2>/dev/null || true; \
	done
	@echo "$(GREEN)Documentation generated!$(NC)"

# Shortcuts
i: init ## Alias for init
p: plan ## Alias for plan
d: deploy ## Alias for deploy
s: status ## Alias for status
