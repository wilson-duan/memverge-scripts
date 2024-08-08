## Table of Contents
These are scripts that I have been using to create Kubernetes clusters on top of VMs. There are a few steps to this process:
1. First, create the VMs, and configure them to have a static IP. This is done by `setup-vm.sh`.
2. Modifying the VMs to be compatible with Kubernetes: modify iptables, disable swap, install kubectl, kubeadm, kubelet, and install crio. This is done by `kubeadm-setup.sh`.
3. Set up the master node, and connect each worker node to the cluster. This is done by `master-setup.sh`.

### Step 1: Create VMs
1. In aep2 server (10.0.0.16), create VMs with this command (you must be root): `virt-clone --original ubuntu-clean --name <name_of_VM> --auto-clone`
    - This creates a clone of an Ubuntu 22.04 VM that I have set up. This is convenient because ubuntu-clean already has many things installed on it (go, git, helm, operator-sdk, etc.), and you do not have to install them again.
2. Start the VM, either using the Cockpit UI (https://10.0.0.16:9090), or using the command `virsh start <name_of_VM>`.
3. Now, you must change the hostname and the static IP of the VM. You must choose an IP address not in use; you can check which IP addresses are in use by running the command on aep2: `arp-scan --localnet`, or by pinging some address you choose. Once you have chosen a hostname and static IP, run the script `./setup-vm.sh <new-hostname> <new-static-ip>`.
4. Reboot the VM, and once it is rebooted, you can ssh into it with the static IP you chose.

### Step 2: Configure VMs
1. There are many things to be installed/configured. All you need to do is run the script: `./kubeadm-setup.sh` and it should set everything up correctly.

### Step 3: Set up Master Node
1. The script `./master-setup.sh <cluster-name> [pod_cidr] [service_cidr]` will handle many things, note that `cluster-name` is a mandatory argument, and `pod_cidr` and `service_cidr` are optional arguments - the script will use the default CIDRs if not provided:
    - Runs `kubeadm init` to initialize the cluster, using the given POD_CIDR and SERVICE_CIDR if provided
    - Installs Calico for CNI
    - Installs a storage class, sets it as the default storage class
    - Modifies the coredns configmap to fix an error that I commonly experience with networking
    - Changes the name of the cluster to `cluster-name`
    - At the end of the script, it prints out a command that you run on your worker nodes to connect the worker nodes to the cluster

### Optional Step: Install NFS-Provisioner
1. The script `setup_nfs.sh` and the `nfs-provisioner.yaml` files are copied from https://github.com/justmeandopensource/kubernetes/tree/master/vagrant-provisioning/misc/nfs-subdir-external-provisioner, I do not take credit for these files. See https://www.youtube.com/watch?v=fHBhFTF7Hls for any help setting up NFS.