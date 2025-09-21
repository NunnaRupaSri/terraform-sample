#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting user data script..."

# Update system
apt update -y
apt install -y nginx ruby-full wget awscli

# Install CodeDeploy agent
echo "Installing CodeDeploy agent..."
cd /tmp
wget https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install
chmod +x ./install
./install auto

# Verify CodeDeploy agent installation
if [ ! -f /opt/codedeploy-agent/bin/codedeploy-agent ]; then
    echo "ERROR: CodeDeploy agent installation failed"
    exit 1
fi

# Create application directory
mkdir -p /var/www/html
chown www-data:www-data /var/www/html

# Start and enable nginx
echo "Starting nginx..."
systemctl start nginx
systemctl enable nginx

# Start and enable CodeDeploy agent
echo "Starting CodeDeploy agent..."
systemctl start codedeploy-agent
systemctl enable codedeploy-agent

# Verify services are running
echo "Verifying services..."
systemctl status nginx --no-pager
systemctl status codedeploy-agent --no-pager

echo "User data script completed successfully"
