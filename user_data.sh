#!/bin/bash
apt update -y
apt install -y nginx ruby-full wget awscli curl

# Install CodeDeploy agent
cd /tmp
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Create application directory
mkdir -p /var/www/html
chown ubuntu:ubuntu /var/www/html
cd /var/www/html

# Start and enable nginx
systemctl start nginx
systemctl enable nginx

# Start CodeDeploy agent
service codedeploy-agent start
service codedeploy-agent status
sleep 5
service codedeploy-agent restart

# Tag instance for CodeDeploy
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 create-tags --region eu-west-1 --resources $INSTANCE_ID --tags Key=CodeDeployReady,Value=true
