#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Check if exactly one argument is provided
if [[ $# -ne 2 ]]; then
   echo "Usage: $0 <new-hostname> <new-ip>"
   exit 1
fi

# Verify that set-hostname.sh exists
if [[ ! -f ./helper/set-hostname.sh ]]; then
   echo "set-hostname.sh is missing"
   exit 1
fi

# Set hostname
chmod +x ./helper/set-hostname.sh
./helper/set-hostname.sh "$1"

# Verify that set-netplan.sh exists
if [[ ! -f ./helper/set-netplan.sh ]]; then
   echo "set-netplan.sh is missing"
   exit 1
fi

# Set netplan
chmod +x ./helper/set-netplan.sh
./helper/set-netplan.sh "$2"
