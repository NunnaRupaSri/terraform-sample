#!/bin/bash
sudo apt update -y
sudo apt install -y nginx ruby-full wget awscli

# Install CodeDeploy agent
cd /tmp
sudo wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
sudo chmod +x ./install
sudo ./install auto

# Create application directory
mkdir -p /var/www/html
sudo chown www-data:www-data /var/www/html

# Start nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Start CodeDeploy agent
sudo service codedeploy-agent start
sudo update-rc.d codedeploy-agent defaults
