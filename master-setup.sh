#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

export IPADDR="$(ip --json a s | jq -r '.[] | if .ifname == "enp1s0" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
export NODENAME=$(hostname -s)
export POD_CIDR="10.1.0.0/16"

sudo kubeadm init --apiserver-advertise-address=$IPADDR  --apiserver-cert-extra-sans=$IPADDR  --pod-network-cidr=$POD_CIDR --node-name $NODENAME --ignore-preflight-errors Swap --cri-socket /var/run/crio/crio.sock

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Printing pods:"
kubectl get po -n kube-system

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml
echo "Calico installed"

join_command=$(kubeadm token create --print-join-command)
echo "Join command: sudo $join_command --cri-socket /var/run/crio/crio.sock"

echo "Master node setup complete"