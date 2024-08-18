#!/bin/bash

# Check if already run
if [ -f /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
    exit 0
fi

# Get sensitive information (adjust for multi-master if needed)
echo "Please provide the following information to initialize the Kubernetes master:"
read -p "Pod Network CIDR (e.g., 10.244.0.0/16): " POD_NETWORK_CIDR
read -p "API Server Advertise Address (this master's IP): " APISERVER_ADVERTISE_ADDRESS
# Additional prompts for multi-master (if applicable):
# read -p "Load Balancer IP (for multi-master): " LOAD_BALANCER_IP
# read -p "Control Plane Endpoint (for multi-master): " CONTROL_PLANE_ENDPOINT

# Install remaining packages
apt-get update && apt-get install -y \
    docker.io kubelet kubeadm kubectl

# Configure Docker (same as for nodes)
cat <<EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl daemon-reload
systemctl restart docker

# Enable kernel modules and settings (same as for nodes)
modprobe overlay
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
echo '1' > /proc/sys/net/ipv4/ip_forward

# Initialize Kubernetes cluster
kubeadm init --pod-network-cidr="${POD_NETWORK_CIDR}" \
  --apiserver-advertise-address="${APISERVER_ADVERTISE_ADDRESS}" \
  # Additional flags for multi-master (if applicable):
  # --control-plane-endpoint "${CONTROL_PLANE_ENDPOINT}" \
  # --upload-certs 

# Configure kubectl for the current user (optional)
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Instructions for joining nodes (displayed after successful init)
echo "Kubernetes master initialized successfully!"
kubeadm token create --print-join-command
