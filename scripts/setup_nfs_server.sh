#!/bin/bash

# Update
apt-get update

# Install NFS server
apt install nfs-kernel-server

# Create NFS directory
mkdir -p /mnt/kubedata

# Set permissions and allow any user to access the folder
chown nobody:nogroup /mnt/kubedata
chmod 777 /mnt/kubedata

# Define access for NFS clients
to_append='/mnt/kubedata '
worker_ips=( $(grep 'worker' cluster_ips.txt | awk '{print $1}') )
for worker_ip in "${worker_ips[@]}"
do
    to_append="$to_append ${worker_ip}(rw,sync,no_subtree_check)"
done
echo $to_append >> /etc/exports

# Make the file share available
exportfs -a

# Restart the NFS kernel
systemctl restart nfs-kernel-server

# Install OpenSSH-Server and modify config file
apt-get install -y openssh-server
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd
