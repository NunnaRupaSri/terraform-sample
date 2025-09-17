#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting user data script..."

# Update system
sudo apt update -y
sudo apt install -y nginx ruby-full wget awscli

# Install CodeDeploy agent
echo "Installing CodeDeploy agent..."
cd /tmp
sudo wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
sudo chmod +x ./install
./install auto

# Verify CodeDeploy agent installation
if [ ! -f /opt/codedeploy-agent/bin/codedeploy-agent ]; then
    echo "ERROR: CodeDeploy agent installation failed"
    exit 1
fi

# Create application directory
mkdir -p /var/www/html
sudo chown www-data:www-data /var/www/html

# Start and enable nginx
echo "Starting nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx

# Start and enable CodeDeploy agent
echo "Starting CodeDeploy agent..."
sudo systemctl start codedeploy-agent
sudo systemctl enable codedeploy-agent

# Verify services are running
echo "Verifying services..."
sudo systemctl status nginx --no-pager
sudo systemctl status codedeploy-agent --no-pager

echo "User data script completed successfully"

