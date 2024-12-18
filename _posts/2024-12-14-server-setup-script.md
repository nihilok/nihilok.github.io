---
layout: post
title: "Server setup script"
date: 2024-12-14
---

Building on [a previous post]({% post_url 2024-12-04-so-its-been-a-year %}), here is a script that automates the setup of a server. When setting up a  new server there are several things that I either do by default (on autopilot) or I forget to do. This script installs and configures various components such as `nginx`, `certbot` for Let's Encrypt SSL certificates, `fail2ban`, `ufw`, and more. It also provides an option to disable password authentication and root login via SSH for added security. Here's the script in full:

```bash
#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

# Function to display error messages
error_exit() {
	echo "Error: $1" >&2
	exit 1
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
	error_exit "This script must be run as root. Use or switch to the root user."
fi

# Logging
LOG_FILE="/var/log/server-setup.sh.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Check which package manager is available and set the update and install commands
if [ -x "$(command -v apt-get)" ]; then
	PKG_UPDATE_CMD="apt-get update"
	PKG_INSTALL_CMD="apt-get install -y"
elif [ -x "$(command -v apk)" ]; then
	PKG_UPDATE_CMD="apk update"
	PKG_INSTALL_CMD="apk add"
elif [ -x "$(command -v dnf)" ]; then
	PKG_UPDATE_CMD="dnf check-update"
	PKG_INSTALL_CMD="dnf install -y"
elif [ -x "$(command -v yum)" ]; then
	PKG_UPDATE_CMD="yum check-update"
	PKG_INSTALL_CMD="yum install -y"
elif [ -x "$(command -v pacman)" ]; then
	PKG_UPDATE_CMD="pacman -Sy"
	PKG_INSTALL_CMD="pacman -S --noconfirm"
else
	echo "Unsupported package manager" >&2
	exit 1
fi

# Check if system uses service or systemctl
if [ -x "$(command -v systemctl)" ]; then
	function start {
		systemctl start $1
		systemctl enable $1
	}
	function restart {
		systemctl restart $1
	}
elif [ -x "$(command -v service)" ]; then
	function start {
		service $1 start
		service $1 enable
	}
	function restart {
		service $1 restart
	}
else
	echo "Unsupported service manager" >&2
	exit 1
fi

# Update and upgrade
echo "Updating package repositories..."
eval $PKG_UPDATE_CMD >/dev/null 2>&1

# Install packages
echo "Installing required packages..."
{
	eval $PKG_INSTALL_CMD git python3-dev python3-pip python3-venv python3-wheel
	eval $PKG_INSTALL_CMD curl
	eval $PKG_INSTALL_CMD nginx
	start nginx
	eval $PKG_INSTALL_CMD certbot python3-certbot-nginx
	eval $PKG_INSTALL_CMD sqlite3
	eval $PKG_INSTALL_CMD fail2ban
	start fail2ban
	eval $PKG_INSTALL_CMD ufw
	ufw allow 'Nginx Full'
	ufw allow 'OpenSSH'
} >/dev/null 2>&1

# Ask user if they would like to enable the firewall
read -p "Would you like to enable the firewall? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	ufw enable >/dev/null 2>&1 <<<y
	echo "Firewall enabled."
else
	echo "Firewall not enabled. Please enable it manually if needed."
fi

# Create a new Nginx server block if the server name is provided and no existing configs are found
NGINX_SERVER_NAME=${1:-""}

NGINX_SERVER_CONFIG="\
server {
    listen 80;
    server_name $NGINX_SERVER_NAME;
    root /var/www/html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}"

if [ "$NGINX_SERVER_NAME" != "" ]; then
	# Remove default Nginx server block if it exists
	if [ -f /etc/nginx/sites-enabled/default ]; then
		echo "Removing link to default nginx server block..."
		rm /etc/nginx/sites-enabled/default >/dev/null 2>&1 || true
	fi

	# Create a new Nginx server block if no existing configs are found except the default
	if [ ! -f /etc/nginx/sites-enabled/* ]; then
		echo "Creating a new Nginx server block..."
		echo "$NGINX_SERVER_CONFIG" >/etc/nginx/sites-available/current
		ln -s /etc/nginx/sites-available/current /etc/nginx/sites-enabled/
		restart nginx
		echo "Check/update the Nginx server block configuration at /etc/nginx/sites-available/current"
	else
		echo "Existing Nginx server config found. No changes made."
	fi
fi

# Ask user if they would like to disable password authentication
read -p "Would you like to disable password authentication? (y/N): " -n 1 -r
echo
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
	echo "Server setup complete!"
	exit 0
fi

# Display warning and prompt for confirmation
echo "************************************************************"
echo "WARNING: This script will now disable SSH password authentication"
echo "         and root login. Ensure you have SSH key-based access"
echo "         configured for all necessary user accounts."
echo "         Disabling these settings without proper SSH keys"
echo "         can lock you out of the server."
echo "************************************************************"
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo

# Check user confirmation
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
	echo "Operation cancelled by the user."
	echo "Server setup complete!"
	exit 0
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.backup_$(date +%F_%T)"

# Backup the current SSH configuration
cp "$SSHD_CONFIG" "$BACKUP_FILE" || error_exit "Failed to create backup of $SSHD_CONFIG."
echo "Backup of sshd_config created at $BACKUP_FILE"

# Function to update or add a configuration directive
update_config() {
	local directive="$1"
	local value="$2"

	if grep -q "^\s*#\?\s*${directive}\s\+" "$SSHD_CONFIG"; then
		# Uncomment and set the directive
		sed -i "s|^\s*#\?\s*${directive}\s\+.*|${directive} ${value}|g" "$SSHD_CONFIG"
	else
		# Append the directive at the end of the file
		echo "${directive} ${value}" >>"$SSHD_CONFIG"
	fi
}

# Disable password authentication
update_config "PasswordAuthentication" "no"

# Disable root login
update_config "PermitRootLogin" "no"

# Disable empty passwords for added security
update_config "PermitEmptyPasswords" "no"

# Disable challenge-response authentication
update_config "ChallengeResponseAuthentication" "no"

# Check SSH configuration syntax
echo "Checking SSH configuration syntax..."
if ! sshd -t; then
	echo "SSH configuration syntax is invalid. Restoring the original configuration."
	cp "$BACKUP_FILE" "$SSHD_CONFIG" || error_exit "Failed to restore the original sshd_config."
	exit 1
fi

# Function to restart SSH service
restart_sshd() {
	local services=("sshd" "ssh")
	for service in "${services[@]}"; do
		if systemctl list-units --type=service | grep -q "${service}.service"; then
			systemctl restart "$service" && return 0
		elif service --status-all 2>/dev/null | grep -q "$service"; then
			service "$service" restart && return 0
		fi
	done
	return 1
}

# Prompt to restart SSH service
read -p "Do you want to restart the SSH service now? (y/N): " -n 1 -r
echo
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
	echo "Restarting SSH service..."
	if ! restart_sshd; then
		error_exit "Failed to restart SSH service. Please restart it manually."
	fi
else
	echo "Please restart the SSH service manually when ready."
fi

echo "SSH password authentication and root login have been successfully disabled."
echo "Server setup complete! Please verify that you can log in using SSH keys before closing your current session."
echo
exit 0

```

This script can be downloaded from [here](https://gist.github.com/nihilok/d57ce168bc643e2ac18c0b54a7877aba) and run on a server with the following commands:

```bash
curl https://gist.githubusercontent.com/nihilok/d57ce168bc643e2ac18c0b54a7877aba/raw/server-setup.sh -o server-setup.sh
chmod +x server-setup.sh
sudo ./server-setup.sh example.com
```

You can omit the server name arg (example.com) if you don't want to create an Nginx server block. The script will install and configure the other components without creating an Nginx server block.
