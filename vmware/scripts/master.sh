 #!/bin/sh

IP_ADDRESS=`hostname -I | awk '{print $2}'`

sudo kubeadm init --apiserver-advertise-address=${IP_ADDRESS} --node-name $(hostname -s) --kubernetes-version=${K8S_VERSION} --ignore-preflight-errors=NumCPU,Mem --pod-network-cidr=${POD_CIDR}

sudo mkdir -p /home/${USER}/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/${USER}/.kube/config

sudo chown -R ${USER}:${USER} /home/${USER}/.kube
sudo chmod 644 /home/${USER}/.kube/config

sudo rm -rf /vargrant/outputs
sudo mkdir -p /vagrant/outputs/.kube

JOIN_CLUSTER_FILE=/vagrant/outputs/join.sh

sudo kubeadm token create --print-join-command > ${JOIN_CLUSTER_FILE}
sudo chmod +x ${JOIN_CLUSTER_FILE}

yes | sudo cp -i /etc/kubernetes/admin.conf /vagrant/outputs/.kube/config

export KUBECONFIG=/home/${USER}/.kube/config

kubectl apply -f https://projectcalico.docs.tigera.io/manifests/calico.yaml

sudo systemctl restart systemd-resolved
sudo swapoff -a && sudo systemctl daemon-reload && sudo systemctl restart kubelet

