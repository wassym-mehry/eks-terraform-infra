# Makefile for EKS Terraform Infrastructure

.PHONY: help init plan apply destroy validate format clean setup-aws

# Default environment
ENV ?= dev

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "EKS Terraform Infrastructure - Available Commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [command]\n\nCommands:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

setup-aws: ## Setup AWS credentials and resources for GitHub Actions
	@echo "$(YELLOW)Setting up AWS credentials...$(NC)"
	@./scripts/setup-aws-credentials.sh

init: ## Initialize Terraform for specified environment
	@echo "$(YELLOW)Initializing Terraform for $(ENV) environment...$(NC)"
	@cd terraform && terraform init -backend-config="environments/$(ENV)/backend.conf"

validate: ## Validate Terraform configuration
	@echo "$(YELLOW)Validating Terraform configuration...$(NC)"
	@cd terraform && terraform validate

format: ## Format Terraform files
	@echo "$(YELLOW)Formatting Terraform files...$(NC)"
	@cd terraform && terraform fmt -recursive

plan: init validate ## Create Terraform execution plan
	@echo "$(YELLOW)Creating Terraform plan for $(ENV) environment...$(NC)"
	@cd terraform && terraform plan -var-file="environments/$(ENV)/terraform.tfvars" -out=tfplan-$(ENV)

apply: plan ## Apply Terraform configuration
	@echo "$(YELLOW)Applying Terraform configuration for $(ENV) environment...$(NC)"
	@cd terraform && terraform apply tfplan-$(ENV)

destroy: ## Destroy Terraform-managed infrastructure
	@echo "$(RED)⚠️  WARNING: This will destroy all infrastructure in $(ENV) environment!$(NC)"
	@echo "Type 'yes' to continue: "
	@read confirm && [ "$$confirm" = "yes" ] || (echo "Aborted" && exit 1)
	@cd terraform && terraform destroy -var-file="environments/$(ENV)/terraform.tfvars" -auto-approve

output: ## Show Terraform outputs
	@echo "$(YELLOW)Terraform outputs for $(ENV) environment:$(NC)"
	@cd terraform && terraform output

state-list: ## List Terraform state resources
	@echo "$(YELLOW)Terraform state resources:$(NC)"
	@cd terraform && terraform state list

kubeconfig: ## Update kubeconfig for the EKS cluster
	@echo "$(YELLOW)Updating kubeconfig...$(NC)"
	@CLUSTER_NAME=$$(cd terraform && terraform output -raw cluster_id) && \
	aws eks update-kubeconfig --region eu-west-1 --name $$CLUSTER_NAME

nodes: kubeconfig ## Show EKS cluster nodes
	@echo "$(YELLOW)EKS cluster nodes:$(NC)"
	@kubectl get nodes -o wide

pods: kubeconfig ## Show all pods in the cluster
	@echo "$(YELLOW)All pods in the cluster:$(NC)"
	@kubectl get pods --all-namespaces

clean: ## Clean up temporary files
	@echo "$(YELLOW)Cleaning up temporary files...$(NC)"
	@find . -name "*.tfplan" -delete
	@find . -name "*.backup" -delete
	@find . -name "cleanup-report-*.txt" -delete

cleanup-resources: ## Run resource cleanup script
	@echo "$(YELLOW)Running resource cleanup script...$(NC)"
	@./scripts/cleanup.sh

security-scan: ## Run basic security checks
	@echo "$(YELLOW)Running basic security checks...$(NC)"
	@echo "Checking for sensitive files..."
	@find . -name "*.tfvars" -not -path "./terraform/environments/*" -exec echo "Warning: Found tfvars file outside environments: {}" \;
	@echo "Checking for hardcoded secrets..."
	@grep -r -i "secret\|password\|key" terraform/ --include="*.tf" --include="*.tfvars" || echo "No obvious secrets found"

install-tools: ## Install required tools (Linux/MacOS)
	@echo "$(YELLOW)Installing required tools...$(NC)"
	@which terraform >/dev/null || (echo "Installing Terraform..." && \
		curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add - && \
		sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" && \
		sudo apt-get update && sudo apt-get install terraform)
	@which kubectl >/dev/null || (echo "Installing kubectl..." && \
		curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
		sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl)
	@which aws >/dev/null || (echo "Please install AWS CLI v2 manually")
	@which jq >/dev/null || (echo "Installing jq..." && sudo apt-get install jq)

# Environment-specific targets
dev: ENV=dev
dev: plan ## Plan for development environment

staging: ENV=staging
staging: plan ## Plan for staging environment

prod: ENV=prod
prod: plan ## Plan for production environment

dev-apply: ENV=dev
dev-apply: apply ## Apply for development environment

staging-apply: ENV=staging
staging-apply: apply ## Apply for staging environment

prod-apply: ENV=prod
prod-apply: apply ## Apply for production environment

# Utility targets
tf-version: ## Show Terraform version
	@terraform version

aws-whoami: ## Show current AWS identity
	@aws sts get-caller-identity

check-prerequisites: ## Check if all prerequisites are installed
	@echo "$(YELLOW)Checking prerequisites...$(NC)"
	@which terraform >/dev/null && echo "$(GREEN)✓ Terraform installed$(NC)" || echo "$(RED)✗ Terraform not found$(NC)"
	@which kubectl >/dev/null && echo "$(GREEN)✓ kubectl installed$(NC)" || echo "$(RED)✗ kubectl not found$(NC)"
	@which aws >/dev/null && echo "$(GREEN)✓ AWS CLI installed$(NC)" || echo "$(RED)✗ AWS CLI not found$(NC)"
	@which jq >/dev/null && echo "$(GREEN)✓ jq installed$(NC)" || echo "$(RED)✗ jq not found$(NC)"
	@which git >/dev/null && echo "$(GREEN)✓ git installed$(NC)" || echo "$(RED)✗ git not found$(NC)"