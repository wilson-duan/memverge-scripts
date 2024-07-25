#!/bin/bash

# Check if the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check if exactly one argument is provided
if [[ $# -ne 1 ]]; then
   echo "Usage: $0 <new-hostname>"
   exit 1
fi

# Set the new hostname
new_hostname=$1
hostnamectl set-hostname "$new_hostname"

# Confirm the hostname change
if [[ $? -eq 0 ]]; then
   echo "Hostname successfully changed to $new_hostname"
else
   echo "Failed to change hostname"
   exit 1
fi