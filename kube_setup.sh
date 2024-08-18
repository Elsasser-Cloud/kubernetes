#!/bin/bash

# Check if already run
if [ -f /etc/kubernetes/kubelet.conf ]; then
    exit 0
fi

# Get sensitive information
echo "Please provide the following information to complete Kubernetes setup:"
read -p "Master Node IP: " MASTER_IP
read -p "Token: " TOKEN
read -p "CA Cert Hash: " CA_CERT_HASH
read -p "This Node's Public IP: " PUBLIC_IP

# Install remaining packages
apt-get update && apt-get install -y \
    docker.io kubelet kubeadm kubectl

# Configure Docker
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

# Enable kernel modules and settings
modprobe overlay
modprobe br_netfilter
echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables
echo '1' > /proc/sys/net/ipv4/ip_forward

# Join Kubernetes cluster
systemctl enable kubelet && systemctl start kubelet
kubeadm join "${MASTER_IP}:6443" --token "${TOKEN}" \
  --discovery-token-ca-cert-hash sha256:"${CA_CERT_HASH}" \
  --node-name $(hostname) --cri-socket /var/run/dockershim.sock \
  --apiserver-advertise-address="${PUBLIC_IP}"
