#!/bin/bash
# Update package lists
sudo yum update -y

# Install dependencies
sudo yum install -y wget

# Add Grafana GPG key and repository
sudo rpm --import https://packages.grafana.com/gpg.key
echo "[grafana]
name=Grafana OSS
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key" | sudo tee /etc/yum.repos.d/grafana.repo

# Update package lists again
sudo yum update -y

# Install Grafana
sudo yum install -y grafana

# Install Loki and Promtail
sudo yum install loki -y promtail

# Configure Loki
sudo tee /etc/loki/config.yml <<EOF
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: debug
  grpc_server_max_concurrent_streams: 1000

common:
  instance_addr: 127.0.0.1
  path_prefix: /tmp/loki
  storage:
    filesystem:
      chunks_directory: /tmp/loki/chunks
      rules_directory: /tmp/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

limits_config:
  metric_aggregation_enabled: true

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

pattern_ingester:
  enabled: true
  metric_aggregation:
    loki_address: localhost:3100

ruler:
  alertmanager_url: http://localhost:9093

frontend:
  encoding: protobuf

# By default, Loki will send anonymous, but uniquely-identifiable usage and configuration
# analytics to Grafana Labs. These statistics are sent to https://stats.grafana.org/
#
# Statistics help us better understand how Loki is used, and they show us performance
# levels for most users. This helps us prioritize features and documentation.
# For more information on what's sent, look at
# https://github.com/grafana/loki/blob/main/pkg/analytics/stats.go
# Refer to the buildReport method to see what goes into a report.
#
# If you would like to disable reporting, uncomment the following lines:
#analytics:
#  reporting_enabled: false
EOF

# Configure Promtail
sudo tee /etc/promtail/config.yml <<EOF
server:
  http_listen_port: 9080
positions:
    filename: /tmp/positions.yaml
clients:
    - url: http://localhost:3100/loki/api/v1/push
scrape_configs:
    - job_name: synthetic_logs
      static_configs:
        - targets:
            - localhost
          labels:
            job: synthetic_logs
            __path__: /var/log/synthetic.log
EOF

# Configure Grafana
sudo tee /etc/grafana/grafana.ini <<EOF
[server]
http_port = 3000
root_url = http://localhost:3000
[paths]
data = /var/lib/grafana
logs = /var/log/grafana
[log]
mode = file
[analytics]
check_for_updates = true
[security]
admin_user = grafana
admin_password = grafana_password
[users]
allow_sign_up = false
EOF

# Configure Grafana to use Loki
sudo tee -a /etc/grafana/provisioning/datasources/loki.yaml <<EOF
apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    jsonData:
      maxLines: 1000
      minTimeRange: 1m
EOF

# Change the user of promtail to root
sudo sed -i 's/User=promtail/User=root/g' /etc/systemd/system/promtail.service

# Enable and start Loki service
sudo systemctl enable loki
sudo systemctl restart loki

# Enable and start Promtail service
sudo systemctl enable promtail
sudo systemctl restart promtail

# Enable and start Grafana service
sudo systemctl enable grafana-server
sudo systemctl restart grafana-server

# Install python3 and build a flask application that logs synthetic logs to log file infrequently
sudo yum install python3 -y
sudo pip3 install flask

sudo tee /var/log/synthetic.log <<EOF
EOF

sudo chown ec2-user:ec2-user /var/log/synthetic.log

tee /home/ec2-user/synthetic.py <<EOF
from flask import Flask
import logging
import time

app = Flask(__name__)

@app.route('/')
def hello_world():
    app.logger.info('Hello, World!')
    return 'Hello, World!'

if __name__ == '__main__':
    logging.basicConfig(filename='/var/log/synthetic.log', level=logging.INFO)
    app.run(host='0.0.0.0', port=5000)
    while True:
        time.sleep(60)
        app.logger.info('Hello, World!')
EOF

nohup python3 /home/ec2-user/synthetic.py > /var/log/synthetic.log 2>&1 &