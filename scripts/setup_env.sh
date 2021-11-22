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

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update && apt-get install -y \
    containerd.io=1.2.13-2 \
    docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs) \
    docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)
cat > /etc/docker/daemon.json <<EOF
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker
systemctl enable docker

# Update repository
apt-get update

# Setup NFS
apt-get install nfs-common

# Set up Kubernetes environment
apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Update repository
apt-get update

# Install kubeadm, Kubelet And Kubectl 
apt-get install -y kubelet=1.19.3-00 kubeadm=1.19.3-00 kubectl=1.19.3-00
apt-mark hold kubelet kubeadm kubectl

if [[ $NODE_TYPE == master ]]
then
    # Init k8s cluster
	kubeadm init --apiserver-advertise-address=$IP --pod-network-cidr=192.168.0.0/16 > output.txt
    start_line=`awk '/kubeadm join/{ print NR; exit }' output.txt`
	end_line=$((start_line + 1))
    awk -v s="$start_line" -v e="$end_line" 'NR >=s && NR <=e {print $0}' output.txt > join_cluster.sh
	rm output.txt
    chmod 700 join_cluster.sh
    mkdir -p $HOME/.kube
    chown vagrant:vagrant $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config 
    chown vagrant:vagrant $HOME/.kube/config
    
    # Install the CALICO pod network
    curl https://docs.projectcalico.org/manifests/calico.yaml -O
    kubectl apply -f calico.yaml
    rm calico.yaml

    # Set up ssh connections with worker nodes
    ./setup_ssh.sh

    # Send join_cluster.sh script to worker nodes
    workers_ips=$(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' cluster_ips.txt | sed -n -e '2,4p')
    for ip in $workers_ips; do
        scp join_cluster.sh root@$ip:/home/vagrant
    done
fi

