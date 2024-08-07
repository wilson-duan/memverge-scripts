#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Make sure the script is given two arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <POD_CIDR> <SERVICE_CIDR> <CLUSTER_NAME>"
    exit 1
fi

export IPADDR="$(ip --json a s | jq -r '.[] | if .ifname == "enp1s0" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
export NODENAME=$(hostname -s)
export POD_CIDR=$1 # 10.1.0.0/16
export SERVICE_CIDR=$2 # 10.96.0.0/12
export CLUSTER_NAME=$3

# Create the kubeadm configuration file
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
nodeRegistration:
  name: $NODENAME
  criSocket: unix:///var/run/crio/crio.sock
  kubeletExtraArgs:
    fail-swap-on: "false"
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
metadata:
  name: $CLUSTER_NAME
kubernetesVersion: 1.28.0
networking:
  podSubnet: $POD_CIDR
  serviceSubnet: $SERVICE_CIDR
apiServer:
  certSANs:
  - $IPADDR
controlPlaneEndpoint: $IPADDR:6443
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
EOF

# Run kubeadm init with the generated configuration file
sudo kubeadm init --config=kubeadm-config.yaml

# Clean up the configuration file
rm kubeadm-config.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Printing pods:"
kubectl get po -n kube-system

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/calico.yaml
echo "Calico installed"

kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
echo "Local path provisioner installed"
# Get the name of the only StorageClass
STORAGECLASS_NAME=$(kubectl get storageclass -o jsonpath='{.items[0].metadata.name}')

# Check if there is exactly one StorageClass
STORAGECLASS_COUNT=$(kubectl get storageclass --no-headers | wc -l)

if [ "$STORAGECLASS_COUNT" -ne 1 ]; then
  echo "Error: There should be exactly one StorageClass. Found $STORAGECLASS_COUNT."
  exit 1
fi

# Edit the StorageClass to add the annotation
kubectl patch storageclass $STORAGECLASS_NAME -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'

echo "StorageClass $STORAGECLASS_NAME updated successfully."

# Define the namespace and configmap name
NAMESPACE=kube-system
CONFIGMAP=coredns

# Replace the forward directive in the CoreDNS ConfigMap
kubectl get configmap ${CONFIGMAP} -n ${NAMESPACE} -o yaml | \
sed 's/forward \. \/etc\/resolv\.conf/forward \. 8.8.8.8 8.8.4.4/' | \
kubectl apply -f -
kubectl rollout restart deployment coredns -n ${NAMESPACE}

echo "CoreDNS ConfigMap updated successfully."

join_command=$(kubeadm token create --print-join-command)
echo "Join command: sudo $join_command --cri-socket unix:///var/run/crio/crio.sock"

echo "Master node setup complete"