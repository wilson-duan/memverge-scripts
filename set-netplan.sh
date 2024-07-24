#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if exactly one argument is provided
if [[ $# -ne 1 ]]; then
   echo "Usage: $0 <new-ip>"
   exit 1
fi

# Path to the netplan configuration file
netplan_file="/etc/netplan/00-installer-config.yaml"

# Predefined configuration content
config_content="network:
    ethernets:
        enp1s0:
            dhcp4: no
            addresses:
                - $1/24
            routes:
                - to: default
                  via: 10.0.1.254
            nameservers:
                addresses:
                    - 10.0.0.250
                    - 8.8.8.8
                    - 8.8.4.4
    version: 2"

# Overwrite the netplan configuration file with the predefined content
echo "$config_content" > "$netplan_file"

# Apply the new netplan configuration
netplan apply

# Confirm the update
if [[ $? -eq 0 ]]; then
    echo "Netplan configuration updated and applied successfully."
else
    echo "Failed to apply the new netplan configuration."
    exit 1
fi