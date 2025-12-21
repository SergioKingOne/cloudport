# CloudPort - Enterprise AWS Migration Infrastructure

A comprehensive Terraform infrastructure for simulating enterprise migration from on-premises to AWS. This project demonstrates hybrid connectivity, centralized security, multi-account governance, and disaster recovery patterns.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS Primary Region (us-east-1)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │  Prod VPC    │   │  Dev VPC     │   │ Shared VPC   │   │ OnPrem VPC   │  │
│  │  10.1.0.0/16 │   │  10.2.0.0/16 │   │ 10.3.0.0/16  │   │ 10.0.0.0/16  │  │
│  │              │   │              │   │              │   │              │  │
│  │ ┌──────────┐ │   │              │   │ ┌──────────┐ │   │ ┌──────────┐ │  │
│  │ │ Fargate  │ │   │              │   │ │ GWLB +   │ │   │ │ Storage  │ │  │
│  │ │ + Aurora │ │   │              │   │ │ Suricata │ │   │ │ Gateway  │ │  │
│  │ └──────────┘ │   │              │   │ └──────────┘ │   │ │ DataSync │ │  │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   │ └──────────┘ │  │
│         │                  │                  │           └──────┬───────┘  │
│         └──────────────────┼──────────────────┘                  │          │
│                            │                                     │          │
│                   ┌────────┴────────┐                            │          │
│                   │ Transit Gateway │◄───────────────────────────┘          │
│                   └────────┬────────┘                                       │
│                            │                                                │
│                   ┌────────┴────────┐                                       │
│                   │  Site-to-Site   │                                       │
│                   │      VPN        │                                       │
│                   └─────────────────┘                                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS DR Region (us-west-2)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ DR VPC (10.10.0.0/16)                                                 │   │
│  │  ┌──────────────┐     ┌──────────────┐                               │   │
│  │  │ Fargate DR   │     │ Aurora       │                               │   │
│  │  │ (Standby)    │     │ (Read Replica)│                              │   │
│  │  └──────────────┘     └──────────────┘                               │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │      Global Accelerator       │
                    │   (Static IPs + Auto Failover)│
                    └───────────────────────────────┘
```

## Components

| Component | Description | AWS Services |
|-----------|-------------|--------------|
| **Foundation** | 4 VPCs simulating multi-account structure | VPC, Subnets, NAT Gateway |
| **Networking Hub** | Centralized connectivity | Transit Gateway, Site-to-Site VPN |
| **Security Inspection** | Traffic inspection with IDS | Gateway Load Balancer, Suricata |
| **Hybrid Storage** | On-prem to cloud file sync | Storage Gateway, S3, Glacier |
| **Data Migration** | Bulk data transfer | DataSync |
| **External Access** | Partner file uploads | Transfer Family (SFTP) |
| **Application** | Containerized workload | ECS Fargate, ALB |
| **Database** | Managed PostgreSQL | Aurora Serverless v2 |
| **DR** | Cross-region failover | Aurora Global, Route 53, Global Accelerator |
| **Monitoring** | Observability & compliance | CloudWatch, CloudTrail |

## Quick Start

### Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate permissions
- AWS account with sufficient quota

### Deploy

```bash
# 1. Initialize
make init

# 2. Review the plan
make plan-primary

# 3. Deploy primary environment
make deploy-primary

# 4. Deploy DR environment (optional)
make deploy-dr
```

### Destroy

```bash
# Destroy everything (DR first, then primary)
make destroy
```

## Project Structure

```
cloudport/
├── Makefile                          # One-command operations
├── README.md                         # This file
├── infrastructure/
│   ├── environments/
│   │   ├── primary/                  # Primary region (us-east-1)
│   │   │   ├── main.tf               # Main configuration
│   │   │   ├── variables.tf          # Input variables
│   │   │   ├── outputs.tf            # Outputs
│   │   │   ├── providers.tf          # Provider config
│   │   │   └── terraform.tfvars      # Variable values
│   │   └── dr/                       # DR region (us-west-2)
│   │       └── ...
│   ├── modules/
│   │   ├── vpc/                      # VPC module
│   │   ├── transit-gateway/          # TGW + VPN
│   │   ├── security-inspection/      # GWLB + Suricata
│   │   ├── storage-gateway/          # File Gateway
│   │   ├── datasync/                 # DataSync
│   │   ├── transfer-family/          # SFTP
│   │   ├── ecs-fargate/              # ECS + ALB
│   │   ├── aurora/                   # Aurora PostgreSQL
│   │   ├── dr/                       # Route 53 + Global Accelerator
│   │   └── monitoring/               # CloudWatch + CloudTrail
│   ├── scripts/
│   │   ├── init.sh                   # Initialize backends
│   │   ├── deploy.sh                 # Deploy helper
│   │   └── destroy.sh                # Destroy helper
│   └── terraform.tfvars.example      # Example configuration
└── .gitignore
```

## Make Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make init` | Initialize Terraform for all environments |
| `make plan` | Show execution plan for all environments |
| `make deploy` | Deploy all environments |
| `make deploy-primary` | Deploy primary environment only |
| `make deploy-dr` | Deploy DR environment only |
| `make destroy` | Destroy all environments (safe order) |
| `make status` | Show current state |
| `make output` | Show all outputs |
| `make lint` | Format and validate |
| `make clean` | Clean up Terraform files |

## Configuration

Edit `infrastructure/environments/primary/terraform.tfvars`:

```hcl
project_name = "cloudport"
environment  = "demo"

# Enable/disable features
enable_security_inspection = true
enable_storage_gateway     = true
enable_datasync            = true
enable_transfer_family     = true

# Aurora capacity
aurora_min_capacity = 0.5
aurora_max_capacity = 4

# SFTP users
sftp_users = {
  partner1 = {
    public_key = "ssh-rsa AAAA..."
  }
}
```

## Cost Estimate

Running this infrastructure costs approximately **$200-300/month**.

| Resource | Est. Monthly Cost |
|----------|------------------|
| NAT Gateways (4x) | $128 |
| Aurora Serverless v2 | $43+ |
| Transit Gateway | $36 |
| Global Accelerator | $18 |
| EC2 (Suricata, Storage GW) | $50+ |
| Other (ELB, S3, etc.) | $25+ |

**Tip:** Run `make destroy` when not actively testing to avoid charges.

## Key Outputs

After deployment, get important endpoints:

```bash
# Application URL
make output-primary | grep app_url

# SFTP endpoint
make output-primary | grep sftp_endpoint

# Global Accelerator IPs
make output-dr | grep global_accelerator_ips

# CloudWatch Dashboard
make output-primary | grep dashboard_url
```

## Disaster Recovery

### Failover Process

1. **Automatic (via Global Accelerator):**
   - Health checks detect primary failure
   - Traffic automatically routes to DR

2. **Manual (Aurora Global Database):**
   ```bash
   # Promote DR Aurora cluster
   aws rds failover-global-cluster \
     --global-cluster-identifier cloudport-demo-global \
     --target-db-cluster-identifier cloudport-demo-dr-aurora-cluster
   ```

### Traffic Control

Adjust traffic distribution via Global Accelerator traffic dials:

```hcl
# In DR terraform.tfvars
primary_traffic_dial   = 100  # 100% to primary
secondary_traffic_dial = 0    # 0% to DR (standby)
```

## Security Features

- **Network Segmentation:** 4 isolated VPCs with Transit Gateway
- **Traffic Inspection:** All traffic routed through Suricata IDS
- **Encryption:** S3, Aurora, and EBS encrypted at rest
- **Guardrails:** IAM policies simulating SCPs
- **Audit:** CloudTrail logging to S3
- **VPC Flow Logs:** Network traffic logging

## Troubleshooting

### Common Issues

1. **Quota exceeded:** Request limit increases for VPCs, EIPs, etc.
2. **Storage Gateway activation:** May require manual activation via console
3. **Aurora Global Database:** Ensure primary is fully deployed before DR

### Debug Commands

```bash
# Check Terraform state
cd infrastructure/environments/primary
terraform state list

# Check specific resource
terraform state show module.vpc_prod.aws_vpc.this

# Force unlock state (if stuck)
terraform force-unlock <lock-id>
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run `make lint` before committing
4. Submit a pull request

## License

MIT License - See LICENSE file for details.
