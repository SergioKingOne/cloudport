################################################################################
# Backend Configuration
# Uncomment and configure for remote state storage
################################################################################

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "cloudport/primary/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# For local development, state is stored locally
# Run `make init` to initialize
