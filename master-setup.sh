#!/bin/bash

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Ensure that the script is run with either 1 or 3 arguments
if [ "$#" -ne 1 ] && [ "$#" -ne 3 ]; then
  echo "Usage: $0 <CLUSTER_NAME> [POD_CIDR] [SERVICE_CIDR]"
  exit 1
fi

# Set default values
DEFAULT_POD_CIDR="10.1.0.0/16"
DEFAULT_SERVICE_CIDR="10.96.0.0/12"

export IPADDR="$(ip --json a s | jq -r '.[] | if .ifname == "enp1s0" then .addr_info[] | if .family == "inet" then .local else empty end else empty end')"
export NODENAME=$(hostname -s)
export CLUSTER_NAME=$1
export POD_CIDR=${2:-$DEFAULT_POD_CIDR}
export SERVICE_CIDR=${3:-$DEFAULT_SERVICE_CIDR}

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

# Change the name of the K8s cluster
# Edit the kubeadm-config ConfigMap to change the cluster name
kubectl get configmap -n kube-system kubeadm-config -o yaml | \
sed "s/clusterName: .*/clusterName: $CLUSTER_NAME/" | \
kubectl apply -f -

# Path to kubeconfig
KUBECONFIG_PATH=~/.kube/config

# Backup the original kubeconfig
cp $KUBECONFIG_PATH $KUBECONFIG_PATH.bak

# Use sed to modify the kubeconfig file
# Update the cluster name in the clusters section
sed -i "s/^\(\s*name:\s*\)kubernetes$/\1$NEW_CLUSTER_NAME/" $KUBECONFIG_PATH

# Update the context cluster reference in the contexts section
sed -i "s/^\(\s*cluster:\s*\)kubernetes$/\1$NEW_CLUSTER_NAME/" $KUBECONFIG_PATH

# Update the context name in the contexts section
sed -i "s/^\(\s*name:\s*\)kubernetes-admin@kubernetes$/\1kubernetes-admin@$NEW_CLUSTER_NAME/" $KUBECONFIG_PATH

# Update the current context to use the new cluster name
sed -i "s/^\(\s*current-context:\s*\)kubernetes-admin@kubernetes$/\1kubernetes-admin@$NEW_CLUSTER_NAME/" $KUBECONFIG_PATH

echo "Changed name of cluster."

join_command=$(kubeadm token create --print-join-command)
echo "Join command: sudo $join_command --cri-socket unix:///var/run/crio/crio.sock"

echo "Master node setup complete"