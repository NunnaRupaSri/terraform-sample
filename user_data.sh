#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting user data script..."

# Update system packages
apt update -y
apt install -y nginx wget awscli

# --- Corrected CodeDeploy agent installation ---
# The standard ruby-full package on newer Ubuntu versions doesn't include ruby-webrick,
# which the CodeDeploy agent installer requires. This installs it explicitly.
apt install -y ruby-full ruby-webrick

# Determine the instance's region dynamically
INSTALLER_URL="https://aws-codedeploy-eu-west-1.s3.eu-west-1.amazonaws.com/latest/install"

echo "Using CodeDeploy agent installer from: $INSTALLER_URL"

# Download and install CodeDeploy agent
cd /tmp
wget "$INSTALLER_URL"
chmod +x ./install

# For Ubuntu 20.04+, a workaround is needed to pipe output to a file
# to prevent installation failures.
UBUNTU_VERSION=$(lsb_release -rs)
if (( $(echo "$UBUNTU_VERSION >= 20.04" | bc -l) )); then
  echo "Installing agent with workaround for Ubuntu 20.04+"
  ./install auto > /tmp/codedeploy_install.log
else
  ./install auto
fi
# --- End of CodeDeploy agent installation block ---

# Create application directory and set permissions
mkdir -p /var/www/html
chown www-data:www-data /var/www/html

# Start and enable nginx
echo "Starting and enabling nginx..."
systemctl start nginx
systemctl enable nginx

# Start and enable CodeDeploy agent
echo "Starting and enabling CodeDeploy agent..."
systemctl start codedeploy-agent
systemctl enable codedeploy-agent

# Check agent status for verification
echo "Verifying CodeDeploy agent status..."
systemctl status codedeploy-agent

echo "User data script completed successfully"
