################################################################################
# Backend Configuration - DR Environment
################################################################################

# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "cloudport/dr/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }
