---
layout: post
title: "Server status monitor bash script"
date: 2024-12-16
---

When managing multiple servers, keeping track of their availability is crucial. Building on an example from "Cybersecurity Ops with bash" by Paul Troncone, I've developed a bash script that provides a simple yet effective way to monitor server status across multiple hosts. Let's break down how this script works and why it can be a valuable tool for system administrators.

```bash
#!/usr/bin/env bash

# For a given list of servers, this script will check the status of the server and notify the user if the server is down.
#
# Usage: ./server_status.sh [-i <interval>] < server_list.txt

declare -i INTERVAL=30 # Default interval is 30 seconds

if [ ! -f /var/log/server_status.log ]; then
        # Check if user has permission to write to /var/log
        if [ ! -w /var/log ]; then
                echo "Cannot write to /var/log/server_status.log; hint: use sudo when running this script for the first time" 1>&2
                exit 1
        fi
        touch /var/log/server_status.log
        chown "$USER" /var/log/server_status.log
        chmod 644 /var/log/server_status.log
fi

while getopts ":i:" opt; do
	case ${opt} in
	i)
		INTERVAL=$OPTARG
		;;
	\?)
		echo "Invalid option: $OPTARG" 1>&2
		;;
	:)
		echo "Invalid option: $OPTARG requires an argument" 1>&2
		;;
	esac
	shift $((OPTIND - 1))
done

while true; do
	clear
	echo 'Server Status Monitor'
	echo 'Status: Scanning ...'
	echo '---------------------------------'
	while read -r server_hostname; do
		server_hostname=$(echo $server_hostname | tr -d '\r')

        if [[ $server_hostname == http* ]]; then
            curl -s -o /dev/null -w "%{http_code}" "$server_hostname" | grep -E '(000|501)' &>/dev/null
            if [ $? -eq 0 ]; then
                tput setaf 1
                echo "Server: $server_hostname is down - $(date)" | tee -a /var/log/server_status.log
                tput setaf 7
            fi
            continue
        fi

		ping -c 1 "$server_hostname" | grep -E '(Destination Host Unreachable|100% packet loss)' &>/dev/null
		if [ $? -eq 0 ]; then
			tput setaf 1
			echo "Server: $server_hostname is down - $(date)" | tee -a /var/log/server_status.log
			tput setaf 7
		fi
	done <"${1:-/dev/stdin}"
	echo ""
	echo "Press [CTRL+C] to stop..."

	declare -i i
	for ((i = $INTERVAL; i > 0; i--)); do
		tput cup 1 0
		echo "Status: Next scan in $i seconds      "
		sleep 1
	done
done
```

## Script Overview

The script allows you to monitor the status of a list of servers, whether they're URLs or hostnames, and provides real-time notifications when a server goes down. Here's how it functions:

```bash
./server_status.sh [-i <interval>] < server_list.txt
```

### Key Features

1. **Flexible Input**: The script can read server names from a file or standard input.
2. **Configurable Scan Interval**: You can specify a custom scan interval (default is 30 seconds).
3. **Logging**: Automatically logs server down events to `/var/log/server_status.log`.
4. **Support for Both Hostnames and URLs**: Can ping traditional servers or check HTTP status codes for web servers.

## Implementation

### Logging Setup

The script first checks if it can create and write to the log file at `/var/log/server_status.log`. If the directory isn't writable, it provides a helpful hint to use `sudo` when running the script for the first time. This ensures proper permissions are set for logging.

### Server Status Checking

The script supports two types of server checks:

```bash
# For traditional servers (hostnames)
ping -c 1 "$server_hostname" | grep -E '(Destination Host Unreachable|100% packet loss)' &>/dev/null

# For web servers (URLs)
curl -s -o /dev/null -w "%{http_code}" "$server_hostname" | grep -E '(000|501)' &>/dev/null
```

This dual approach allows monitoring of both network-level connectivity for traditional servers and HTTP availability for web services.

### User Experience

The script provides a clean, interactive terminal interface:
- Colorized output (red for down servers)
- Countdown timer to next scan
- Option to stop monitoring with `CTRL+C`

### Usage Example

Create a `server_list.txt` with your servers:
```
example.com
https://mywebsite.com
192.168.1.100
```

Then run the script:
```bash
./server_status.sh -i 60 < server_list.txt  # Scan every 60 seconds
```

## Considerations and Warnings

As with any system monitoring script, be cautious:
- Ensure you have permission to monitor the servers
- Be mindful of network load, especially with frequent scans
- The script is best used in controlled, internal network environments
- Unless the hostname starts with `http`, the script assumes it's a traditional server and uses `ping` for monitoring; therefore, it may not work for all types of servers if they don't respond to ICMP requests (I had to add a custom rule to an AWS security group to allow ICMP traffic for this script to work for my EC2 instances)

## Conclusion

This bash script offers a lightweight, flexible solution for monitoring server availability. It demonstrates the power of bash scripting in system administration tasks, providing a simple yet effective tool for keeping an eye on your infrastructure.

Remember to always test scripts in a staging environment before deploying to production, and customize the script to fit your specific monitoring needs.

Happy scripting!
