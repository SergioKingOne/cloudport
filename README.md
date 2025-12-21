# CloudPort

Enterprise AWS migration infrastructure with multi-region DR, centralized security inspection, and hybrid connectivity.

![Architecture](infrastructure/diagrams/cloudport-architecture.png)

## Deploy

```bash
make init    # Initialize Terraform
make plan    # Review changes
make deploy  # Deploy all (primary + DR)
```

## Structure

```
infrastructure/
├── environments/
│   ├── primary/     # us-east-1: Prod, Dev, Shared, OnPrem VPCs
│   └── dr/          # us-west-2: DR VPC with Aurora replica
└── modules/
    ├── vpc/                  # VPC with public/private subnets, NAT, flow logs
    ├── transit-gateway/      # Hub-spoke networking, VPN support
    ├── aurora/               # PostgreSQL Serverless v2, global cluster
    ├── ecs-fargate/          # ALB + Fargate service, auto-scaling
    ├── security-inspection/  # GWLB + Suricata IDS
    ├── storage-gateway/      # File Gateway with S3 + Glacier lifecycle
    ├── datasync/             # Scheduled data migration to S3
    ├── transfer-family/      # SFTP server for partners
    ├── dr/                   # Route 53 failover + Global Accelerator
    └── monitoring/           # CloudWatch dashboard, CloudTrail, alerts
```

## Network

| VPC | CIDR | Region |
|-----|------|--------|
| Production | 10.1.0.0/16 | us-east-1 |
| Development | 10.2.0.0/16 | us-east-1 |
| Shared Services | 10.3.0.0/16 | us-east-1 |
| On-Premises | 10.0.0.0/16 | us-east-1 |
| DR | 10.10.0.0/16 | us-west-2 |

## Configuration

```hcl
# infrastructure/environments/primary/variables.tf

# Toggle features
enable_security_inspection = true   # GWLB + Suricata
enable_storage_gateway     = true   # File Gateway
enable_datasync            = true   # Data migration
enable_transfer_family     = true   # SFTP
enable_vpn                 = false  # Site-to-Site VPN

# Application
app_container_image = "nginx:alpine"
aurora_min_capacity = 0.5  # ACUs
aurora_max_capacity = 4
```

## Commands

```bash
make deploy-primary   # Deploy only primary region
make deploy-dr        # Deploy only DR region
make destroy          # Tear down (DR first, then primary)
make output           # Show endpoints and connection strings
make cost             # Estimate costs (requires infracost)
```

## Diagram

Regenerate with [awsdac](https://github.com/awslabs/diagram-as-code):

```bash
awsdac infrastructure/diagrams/architecture.yaml -o infrastructure/diagrams/cloudport-architecture.png
```
