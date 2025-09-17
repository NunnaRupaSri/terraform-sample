#!/bin/bash
apt update -y
apt install -y nodejs npm ruby wget awscli

# Install CodeDeploy agent
cd /home/ubuntu
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Create application directory
mkdir -p /var/www/html
chown ubuntu:ubuntu /var/www/html

# Start and enable CodeDeploy agent
systemctl start codedeploy-agent
systemctl enable codedeploy-agent

# Wait and restart agent
sleep 10
systemctl restart codedeploy-agent

# Tag instance for CodeDeploy
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --region eu-west-1 --resources $INSTANCE_ID --tags Key=CodeDeployReady,Value=true
