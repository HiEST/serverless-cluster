#!/bin/bash

# Extracting workers ips from input file
workers_ips=$(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' cluster_ips.txt | sed -n -e '2,4p')

# Generate a pair of ssh keys
ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -N ""

# Set the public key to the authorized_keys file
cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys

# Copy the public key to all workers
for ip in $workers_ips
do
    sshpass -p root ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@$ip
done

# Copy the public key to nfs server
sshpass -p root ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@10.0.26.204

