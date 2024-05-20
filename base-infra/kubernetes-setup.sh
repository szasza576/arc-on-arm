if [ -z ${K8sVersion+x} ]; then K8sVersion="v1.28"; fi
if [ -z ${PodCIDR+x} ]; then PodCIDR="172.16.0.0/16"; fi
if [ -z ${ServiceCIDR+x} ]; then ServiceCIDR="172.17.0.0/16"; fi
if [ -z ${IngressRange+x} ]; then IngressRange="192.168.0.191-192.168.0.199"; fi
if [ -z ${MasterIP+x} ]; then MasterIP="192.168.0.190"; fi
if [ -z ${MasterName+x} ]; then MasterName="kube-master"; fi
if [ -z ${NFSCIDR+x} ]; then NFSCIDR="192.168.0.0/24"; fi


# Base update
sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
sudo apt update
sudo apt upgrade -u


# Install base tools
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    gnupg2 \
    lsb-release \
    mc \
    curl \
    software-properties-common \
    net-tools \
    nfs-common \
    dstat \
    git \
    curl \
    htop \
    nano \
    bash-completion \
    vim \
    jq


# Disable Swap
sudo sed -i '/swap/ s/^\(.*\)$/#\1/g' /etc/fstab
sudo swapoff -a
sudo systemctl disable swapfile.swap
sudo systemctl stop swapfile.swap


# Configure hosts file and hostname
sudo hostnamectl set-hostname $MasterName
echo "$MasterIP $MasterName" | sudo tee -a /etc/hosts


# Enable kernel modules and setup sysctl
sudo modprobe overlay
sudo modprobe br_netfilter

echo overlay | sudo tee -a /etc/modules
echo br_netfilter | sudo tee -a /etc/modules

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
fs.inotify.max_user_instances=524288
EOF

sudo sysctl --system


# Install containerd and docker-ce
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Fix containerd
sudo tee /etc/crictl.yaml<<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
pull-image-on-create: false
EOF

# Add the repository to apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt install -y containerd.io docker-ce docker-ce-cli

# Configure containerd
sudo bash -c "containerd config default > /etc/containerd/config.toml"
sudo sed -i "s+SystemdCgroup = false+SystemdCgroup = true+g" /etc/containerd/config.toml

sudo systemctl daemon-reload 
sudo systemctl restart containerd
sudo systemctl enable containerd

sudo usermod -aG docker $(ls /home/)
newgrp docker


# Install kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8sVersion}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8sVersion}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt -y install kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo 'source <(kubectl completion bash)' >> /home/*/.bashrc

#Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install -y helm


# Configure master node
sudo systemctl enable kubelet
sudo kubeadm config images pull

cat << EOF > kubeadm.conf
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
networking:
  dnsDomain: cluster.local
  serviceSubnet: $ServiceCIDR
  podSubnet: $PodCIDR
controlPlaneEndpoint: $MasterName
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
evictionHard:
    memory.available:  "100Mi"
    nodefs.available:  "2%"
    nodefs.inodesFree: "2%"
    imagefs.available: "2%"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
EOF

sudo kubeadm init --config kubeadm.conf

mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Waiting for the K8s API server to come up
test=$(kubectl get pods -A 2>&1)
while ( echo $test | grep -q "refuse\|error" ); do echo "API server is still down..."; sleep 5; test=$(kubectl get pods -A 2>&1); done

kubectl taint nodes --all node-role.kubernetes.io/control-plane-
kubectl label nodes --all node.kubernetes.io/exclude-from-external-load-balancers-

# Configre Calico as network plugin
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml

curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml -s -o /tmp/custom-resources.yaml
sed -i "s+192.168.0.0/16+$PodCIDR+g" /tmp/custom-resources.yaml
sed -i "s+blockSize: 26+blockSize: 24+g" /tmp/custom-resources.yaml
kubectl create -f /tmp/custom-resources.yaml
rm /tmp/custom-resources.yaml


# Configure MetalLB
helm repo add metallb https://metallb.github.io/metallb

kubectl create ns metallb-system
kubectl label namespace metallb-system pod-security.kubernetes.io/enforce=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/audit=privileged
kubectl label namespace metallb-system pod-security.kubernetes.io/warn=privileged
kubectl label namespace metallb-system app=metallb
helm install metallb metallb/metallb -n metallb-system --wait \
  --set crds.validationFailurePolicy=Ignore

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: local-pool
  namespace: metallb-system
spec:
  addresses:
  - $IngressRange
EOF

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: advertizer
  namespace: metallb-system
EOF

# Setup NFS share if needed
sudo apt install -y nfs-kernel-server
sudo mkdir -p /mnt/k8s-pv-data
sudo chown -R nobody:nogroup /mnt/k8s-pv-data/
sudo chmod 777 /mnt/k8s-pv-data/

sudo tee -a /etc/exports<<EOF
/mnt/k8s-pv-data  ${NFSCIDR}(rw,sync,no_subtree_check)
EOF

sudo exportfs -a
sudo systemctl restart nfs-kernel-server

# Install NFS-provisioner
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    -n kube-system \
    --set nfs.server=$MasterIP \
    --set nfs.path=/mnt/k8s-pv-data \
    --set storageClass.name=default \
    --set storageClass.defaultClass=true

# Install Metrics Server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server \
    --set args={--kubelet-insecure-tls} \
    -n kube-system
