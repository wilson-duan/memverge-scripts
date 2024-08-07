#!/bin/bash

# Reset the kubeadm cluster
sudo kubeadm reset --cri-socket=unix:///var/run/crio/crio.sock -f

# Remove the .kube directory
rm -rf ~/.kube
rm -rf /etc/kubernetes

# Flush iptables rules
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

# Remove CNI configurations
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni/
sudo rm -rf /opt/cni/bin

# Restart container runtime and clean up containers and images (containerd)
sudo systemctl restart crio