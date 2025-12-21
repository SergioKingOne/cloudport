#!/bin/bash
set -e

# Log output to file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Suricata IDS setup..."

# Update system
dnf update -y

# Install required packages
dnf install -y suricata python3-pip nginx jq

# Install CloudWatch agent
dnf install -y amazon-cloudwatch-agent

# Enable IP forwarding for GENEVE tunnel
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Configure Suricata
cat > /etc/suricata/suricata.yaml <<'EOF'
%YAML 1.1
---
vars:
  address-groups:
    HOME_NET: "[10.0.0.0/8,172.16.0.0/12,192.168.0.0/16]"
    EXTERNAL_NET: "!$HOME_NET"
  port-groups:
    HTTP_PORTS: "80"
    SHELLCODE_PORTS: "!80"
    SSH_PORTS: "22"

default-log-dir: /var/log/suricata/

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert
        - http
        - dns
        - tls
        - files
        - ssh
        - flow

  - fast:
      enabled: yes
      filename: fast.log

af-packet:
  - interface: eth0
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

# GENEVE tunnel support for GWLB
app-layer:
  protocols:
    geneve:
      enabled: yes

# IDS mode (not IPS - we're just alerting)
stream:
  memcap: 64mb
  checksum-validation: yes

# Performance tuning
detect:
  profile: medium
  custom-values:
    toclient-groups: 3
    toserver-groups: 25
  sgh-mpm-context: auto
  inspection-recursion-limit: 3000

# Threading
threading:
  set-cpu-affinity: no
  detect-thread-ratio: 1.0
EOF

# Download and extract rules
echo "Downloading Suricata rules..."
cd /tmp
curl -L -o emerging.rules.tar.gz "${suricata_rules_url}"
tar -xzf emerging.rules.tar.gz -C /etc/suricata/
mv /etc/suricata/rules/* /var/lib/suricata/rules/ 2>/dev/null || true

# Update Suricata rules configuration
suricata-update

# Enable and start Suricata
systemctl enable suricata
systemctl start suricata

# Configure nginx for health checks
cat > /etc/nginx/conf.d/health.conf <<'EOF'
server {
    listen 80;
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

# Remove default nginx config
rm -f /etc/nginx/conf.d/default.conf

# Enable and start nginx
systemctl enable nginx
systemctl start nginx

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/suricata/eve.json",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/eve.json",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/suricata/fast.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/fast.log",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "Suricata",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "net": {
        "measurement": ["bytes_sent", "bytes_recv", "packets_sent", "packets_recv"],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Suricata IDS setup complete!"
