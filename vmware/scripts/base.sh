#!/bin/sh

sudo useradd -m -s /bin/bash -U $USER -u 666 --group sudo
sudo cp -pr /home/vagrant/.ssh /home/${USER}/.ssh
sudo mv /tmp/id_rsa.pub /home/${USER}/.ssh/authorized_keys
sudo chown -R ${USER}:${USER} /home/${USER}

# disable swap 
sudo swapoff -a
# keeps the swaf off during reboot
sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab

sudo sed -i '/^nameserver/c nameserver 8.8.8.8' /etc/resolv.conf
sudo sed -i "s|http://us.|http://|g" /etc/apt/sources.list

sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release net-tools jq

IP_ADDRESS=`hostname -I | awk '{print $2}'`

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf 
overlay 
br_netfilter 
EOF

sudo modprobe overlay 
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf net.bridge.bridge-nf-call-iptables = 1 
net.ipv4.ip_forward = 1 
net.bridge.bridge-nf-call-ip6tables = 1 
EOF

sudo sysctl --system
sudo apt-get update && sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo echo '1' > /proc/sys/net/ipv4/ip_forward
sudo sysctl --system

# Install Kubernetes components
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=${K8S_VERSION}-00 kubeadm=${K8S_VERSION}-00 kubectl=${K8S_VERSION}-00 kubernetes-cni
sudo apt-mark hold kubelet kubeadm kubectl 

sudo sed -i "s|/usr/bin/kubelet|/usr/bin/kubelet --node-ip=${IP_ADDRESS}|g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl restart kubelet

sudo modprobe overlay
sudo modprobe br_netfilter

service systemd-resolved restart
