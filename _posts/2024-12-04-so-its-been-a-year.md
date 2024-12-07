---
title: "So, it's been a year! (Bash script to disable password authentication for SSH)"
date: 2024-12-04
---

*Sharing one of my recent bash scripts for automating server setup that improves security by disabling ssh password authentication and root login.*

So, it's been a year since my last post! Damned work and ADHD getting in the way. That said, I've learnt a great deal in the past year: started following an AWS Developer Associate course, before distractions got the better of me and I decided to go it alone. Flailing wildly in the dark, and armed with the fragments of knowledge I've learnt on the job, I managed to come up with a pretty neat (albeit legally questionable) app that downloads and extracts MP3s from Youtube and other streaming services, that utilised 2 separate AWS Lambdas and SNS, as well as DynamoDB and the Python Telegram Bot SDK. Check out the code [here](https://github.com/nihilok/dlbot-micro). Unfortunately, YouTube very quickly started blocking AWS IPs from accessing their API, even when logged in with my premium account, so I had to take a step back and [rewrite the app](https://github.com/nihilok/dlbot-local) to run on a single server which I can just run on a local machine.

Anyway, enough about my coding adventures – let me show you this bash script I've been tinkering with that's basically my love letter to server security.

We've all been there: you spin up a new server, and it's about as secure as a chocolate padlock, and there's so many different things I find myself having to remember/read how to do every time. Enter my ridiculously over-engineered bash script that's basically a bouncer for your SSH config, kicking out password authentication and root logins faster than you can say "cybersecurity", and it does all this with some pretty slick bash kung-fu that'll make even seasoned sysadmins do a double-take.

Here's the full script:

```bash
#!/bin/bash

# Script to disable SSH password authentication and root login
# Usage: Run as root or with sudo

set -euo pipefail
IFS=$'\n\t'

# Logging
LOG_FILE="/var/log/disable_ssh.sh.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to display error messages
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root. Use sudo or switch to the root user."
fi

# Display warning and prompt for confirmation
echo "************************************************************"
echo "WARNING: This script will disable SSH password authentication"
echo "         and root login. Ensure you have SSH key-based access"
echo "         configured for all necessary user accounts."
echo "         Disabling these settings without proper SSH keys"
echo "         can lock you out of the server."
echo "************************************************************"
read -p "Do you want to proceed? (y/N): " confirm

# Check user confirmation
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled by the user."
    exit 0
fi

# Variables
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
        echo "${directive} ${value}" >> "$SSHD_CONFIG"
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
read -p "Do you want to restart the SSH service now? (y/N): " restart_confirm
if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
    echo "Restarting SSH service..."
    if ! restart_sshd; then
        error_exit "Failed to restart SSH service. Please restart it manually."
    fi
else
    echo "Please restart the SSH service manually when ready."
fi

echo "SSH password authentication and root login have been successfully disabled."
echo "Please verify that you can log in using SSH keys before closing your current session."

exit 0
```

Let me break down some of the cooler parts that I learnt from crafting this script, that *might* actually teach you something:

#### `set -euo pipefail`

Most people see this and their eyes glaze over. But this little line is basically telling bash, "If anything goes wrong, STOP EVERYTHING." It's like having a really anxious friend who immediately hits the emergency brake if something seems off.

- `-e`: If any command fails, the script dies immediately
- `-u`: Treat any undefined variables like a crime scene
- `-o pipefail`: Makes sure that if ANY part of a pipeline fails, the whole thing is considered a failure

Essentially, this prevents those sneaky silent failures that can turn your script into a ticking time bomb.

#### Internal Field Separator

The `IFS=$'\n\t'` sets the Internal Field Separator (IFS) in Bash, and it's a subtle but important line for improving script safety and predictability.

- By default, IFS is set to space, tab, and newline
- `$'\n\t'` explicitly sets IFS to only newline and tab characters
- This means that `file name with spaces.txt` will always be treated as a single item, rather than each word being interpreted as an individual argument.

#### Logging to file and stdout

```bash
LOG_FILE="/var/log/disable_ssh.sh.log"
exec > >(tee -a "$LOG_FILE") 2>&1
```

This little snippet is basically creating a breadcrumb trail of everything the script does. It logs to both the console AND a file. So if something goes wrong, you've got a complete crime scene report.

#### The Configuration Update Wizard

My favorite function in the script is `update_config()` which uses some `grep` and `sed` dark magic to perform the following:

- If a setting exists but is commented out? Uncomment it.
- Setting doesn't exist? Add it to the end of the file.
- Existing setting? Set the value to the provided value

The function is then used to set the 4 different config options that need to be updated.

Pretty neat, right?

#### Fail-Safe Mechanisms

The script has more safety nets than a circus trapeze act:
- Checks SSH config syntax before applying changes
- Creates a backup of your original config
- Requires explicit user confirmation
- Supports multiple ways of restarting the SSH service

### Pro Tips for Using This Script

1. **Always have a backup access method** (console access is your friend)
2. **Ensure SSH keys are set up BEFORE running**
3. **Test in a staging environment first**

### Download and Use

```sh
wget https://gist.githubusercontent.com/nihilok/47dad2f364ca4cba8b456fd209dcfede/raw/5432d5875eccb5a4eaf9f506c02c1d2ff551a708/disable-password-and-root-login-ssh.sh
chmod +x disable-password-and-root-login-ssh.sh
sudo ./disable-password-and-root-login-ssh.sh
```

Is it overkill? Maybe. Was it fun to write? Absolutely (with some help from Claude.ai 🙈)!

Catch you in another year when I've got more random tech shenanigans to share! 🚀🔒
