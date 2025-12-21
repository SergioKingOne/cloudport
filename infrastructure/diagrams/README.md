# CloudPort Architecture Diagrams

This directory contains architecture diagrams for the CloudPort enterprise AWS migration infrastructure.

## Prerequisites

Install [diagram-as-code](https://github.com/awslabs/diagram-as-code):

```bash
# macOS
brew install awsdac

# Or via Go (requires Go 1.21+)
go install github.com/awslabs/diagram-as-code/cmd/awsdac@latest
```

## Generate Diagrams

```bash
# From this directory
awsdac architecture.yaml -o cloudport-architecture.png

# Or from project root
awsdac infrastructure/diagrams/architecture.yaml -o infrastructure/diagrams/cloudport-architecture.png
```

## Architecture Overview

The diagram shows the complete CloudPort infrastructure:

### Primary Region (us-east-1)

| VPC | CIDR | Components |
|-----|------|------------|
| Production | 10.1.0.0/16 | ALB, ECS Fargate, Aurora (Writer + Reader) |
| Development | 10.2.0.0/16 | Dev workloads |
| Shared Services | 10.3.0.0/16 | Gateway Load Balancer, Suricata IDS |
| On-Premises Sim | 10.0.0.0/16 | Storage Gateway, DataSync, Transfer Family |

### DR Region (us-west-2)

| VPC | CIDR | Components |
|-----|------|------------|
| DR | 10.10.0.0/16 | ALB (standby), ECS (minimal), Aurora (Read Replica) |

### Global Services

- **Global Accelerator**: Static anycast IPs with automatic failover
- **Route 53**: DNS failover routing with health checks
- **Aurora Global Database**: Cross-region replication

## Link Legend

| Color | Meaning |
|-------|---------|
| Black (solid) | Active traffic flow |
| Black (dashed) | Standby/failover paths |
| Orange | Security inspection flow (GWLB + Suricata) |
| Blue | Database replication |
| Teal | Data migration (Storage GW, DataSync, SFTP) |
| Red (dashed) | DR failover path |

## Updating the Diagram

1. Edit `architecture.yaml`
2. Regenerate: `awsdac architecture.yaml -o cloudport-architecture.png`
3. Commit both files

## Resources

- [diagram-as-code documentation](https://github.com/awslabs/diagram-as-code)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
