#!/bin/bash
# Update package lists
sudo yum update -y

# Install dependencies
sudo yum install -y wget

# Install Docker
sudo amazon-linux-extras install docker -y
sudo systemctl enable docker
sudo systemctl start docker

# Update package lists again
sudo yum update -y

# Copy Loki and Promtail configuration files
mkdir loki
cd loki
sudo cp -p /tmp/config/loki-config.yml ./loki-config.yaml
sudo cp -p /tmp/config/promtail-config.yml ./promtail-config.yaml
sudo cp -p /tmp/config/loki.yaml ./loki.yaml
sudo cp -p /tmp/config/grafana.ini ./grafana.ini
sudo cp -p /tmp/config/dashboard.yaml ./dashboard.yaml
sudo cp -p /tmp/Synthetic_log_dashboard.json ./Synthetic_log_dashboard.json

# # Create docker containers for Loki, Promtail and Grafana
sudo docker run --name loki -d -v $(pwd):/mnt/config -p 3100:3100 grafana/loki:3.4.1 -config.file=/mnt/config/loki-config.yaml
sudo docker run --name promtail -d -v $(pwd):/mnt/config -v /var/log:/var/log --link loki grafana/promtail:3.4.1 -config.file=/mnt/config/promtail-config.yaml
sudo docker create --name grafana -p 3000:3000 grafana/grafana

sudo docker cp $(pwd)/grafana.ini grafana:/etc/grafana/grafana.ini
sudo docker cp $(pwd)/dashboard.yaml grafana:/etc/grafana/provisioning/dashboards/dashboard.yaml
sudo docker cp $(pwd)/Synthetic_log_dashboard.json grafana:/etc/grafana/provisioning/dashboards/Synthetic_log_dashboard.json
sudo docker cp $(pwd)/loki.yaml grafana:/etc/grafana/provisioning/datasources/loki.yaml

sudo docker start grafana


# # Configure Grafana
# sudo tee /etc/grafana/grafana.ini <<EOF
# [server]
# http_port = 3000
# root_url = http://localhost:3000
# [paths]
# data = /var/lib/grafana
# logs = /var/log/grafana
# [log]
# mode = file
# [analytics]
# check_for_updates = true
# [security]
# admin_user = grafana
# admin_password = grafana_password
# [users]
# allow_sign_up = false
# EOF

# # Configure Grafana to use Loki
# sudo tee -a /etc/grafana/provisioning/datasources/loki.yaml <<EOF
# apiVersion: 1
# datasources:
#   - name: Loki
#     type: loki
#     access: proxy
#     url: http://localhost:3100
#     jsonData:
#       maxLines: 1000
#       minTimeRange: 1m
# EOF

# sudo tee /etc/grafana/provisioning/dashboards/dashboard.yaml <<EOF
# apiVersion: 1
# providers:
#   - name: 'Synthetic Logs'
#     orgId: 1
#     folder: ''
#     type: file
#     disableDeletion: false
#     editable: true
#     options:
#       path: /etc/grafana/provisioning/dashboards
# EOF

# # Enable and start Grafana service
# sudo systemctl enable grafana-server
# sudo systemctl restart grafana-server

# # Install python3 and build a flask application that logs synthetic logs to log file infrequently
# sudo yum install python3 -y
# sudo pip3 install flask

# sudo tee /var/log/synthetic.log <<EOF
# EOF

# sudo chown ec2-user:ec2-user /var/log/synthetic.log

# tee /home/ec2-user/synthetic.py <<EOF
# from flask import Flask
# import logging
# import time

# app = Flask(__name__)

# @app.route('/')
# def hello_world():
#     app.logger.info('Hello, World!')
#     return 'Hello, World!'

# if __name__ == '__main__':
#     logging.basicConfig(filename='/var/log/synthetic.log', level=logging.INFO)
#     app.run(host='0.0.0.0', port=5000)
#     while True:
#         time.sleep(60)
#         app.logger.info('Hello, World!')
# EOF

# nohup python3 /home/ec2-user/synthetic.py > /var/log/synthetic.log 2>&1 &