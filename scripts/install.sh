#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
apt update -y
apt install -y nginx ruby-full wget awscli

# Install CodeDeploy agent
cd /tmp
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Create application directory
mkdir -p /var/www/html
chown www-data:www-data /var/www/html

# Start nginx
systemctl start nginx
systemctl enable nginx

# Start CodeDeploy agent
service codedeploy-agent start
service codedeploy-agent status
