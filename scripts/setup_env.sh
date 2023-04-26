#!/bin/bash

function usage(){
    echo "Usage: ./setup_env.sh  -type 'node_type' -name 'node_hostname' -ip 'node_ip'"
    echo "  -type 'node_type'       specify the type of the node (master or worker)"
    echo "  -name 'node_hostname'   specify the node hostname"
    echo "  -ip   'node_ip'         specify the node ip"
}

#Check if the three required arguments are given
if [ $# -lt 6 ]
then
    echo "ERROR: you have to provide the type, the name and the IP address of the node!"
    usage
    exit 1
fi

#Read the given arguments
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in 
    -type) NODE_TYPE=$2
        if ! [[ $NODE_TYPE == master || $NODE_TYPE == worker ]]
        then
            echo "ERRROR: the note type can be either 'master' or 'worker'!"
            exit 1
        fi
        shift
        ;;
    -name) NODE_HOSTNAME=$2
        shift
        ;;
    -ip) IP=$2
        if ! [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
        then 
            echo "ERROR: the given value is not a valid IP address!"
            exit 1
        fi
        shift
        ;;
    *) echo "ERROR: illegal argument key $key"
        usage
        exit 1
        ;;
    esac
    shift
done

# Update repository
apt-get update

# Setup root password
passwd <<EOF
root
root
EOF

# Turn off swap space
swapoff -a

# Store old hostname
OLD_HOSTNAME=$(hostname)

# Update the hostname
hostname $NODE_HOSTNAME

# Update hosts file with cluster's IP addresses
[ $(grep -cxFf cluster_ips.txt <(sort -u /etc/hosts)) = $(sort -u cluster_ips.txt | wc -l) ]
present=$?
if ! [[ $present -eq 0 ]]
then
	cat cluster_ips.txt | sed -i -e '1r /dev/stdin' /etc/hosts
	sed -i "s/$OLD_HOSTNAME/$NODE_HOSTNAME/g" /etc/hosts
fi

# Setting Static IP Addresses
cat <<EOT >> /etc/network/interfaces
auto enp0s8
iface enp0s8 inet static
address $IP
EOT

# Install OpenSSH-Server and modify config file
apt-get install -y openssh-server
if [[ $NODE_TYPE == worker ]]
then
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
else
    apt-get install -y sshpass
fi

# Update repository
apt-get update

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update -y
sudo apt remove kubelet kubeadm kubectl
sudo apt -y install vim git curl wget kubelet=1.26.0-00 kubeadm=1.26.0-00 kubectl=1.26.0-00
sudo apt-mark hold kubelet kubeadm kubectl

sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#Install and configure containerd 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt remove -y containerd.io 
sudo apt update -y
wget https://github.com/containerd/containerd/releases/download/v1.6.16/containerd-1.6.16-linux-amd64.tar.gz -P /tmp/
tar Cxzvf /usr/local /tmp/containerd-1.6.16-linux-amd64.tar.gz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -P /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
wget https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64 -P /tmp/
sudo install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

#Start containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

if [[ $NODE_TYPE == master ]]
then
    # Init k8s cluster
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=v1.26.0 --control-plane-endpoint $IP --node-name k8s-master  > output.txt
    start_line=`awk '/kubeadm join/{ print NR; exit }' output.txt`
	end_line=$((start_line + 1))
    awk -v s="$start_line" -v e="$end_line" 'NR >=s && NR <=e {print $0}' output.txt > join_cluster.sh
	rm output.txt
    chmod 700 join_cluster.sh
    mkdir -p $HOME/.kube
    chown vagrant:vagrant $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
    chown vagrant:vagrant $HOME/.kube/config
    export KUBECONFIG=$HOME/.kube/config

    # Install the CALICO pod network
    {
    echo "kind: ConfigMap"
    echo "apiVersion: v1"
    echo "metadata:"
    echo "  name: kubernetes-services-endpoint"
    echo "  namespace: kube-system"
    echo "data:"
    echo "  KUBERNETES_SERVICE_HOST: $IP"
    echo "  KUBERNETES_SERVICE_PORT: 6443"
    } >> calico_config_map.yaml
    kubectl apply -f calico_config_map.yaml

    curl https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml -O
    kubectl apply -f calico.yaml

    # Set up ssh connections with worker nodes
    ./setup_ssh.sh

    # Send join_cluster.sh script to worker nodes
    workers_ips=$(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' cluster_ips.txt | awk 'NR>1' )
    for ip in $workers_ips; do
        scp join_cluster.sh root@$ip:/home/vagrant
    done
fi

