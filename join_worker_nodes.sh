# Generate a new token
kubeadm token create --print-join-command > join_cluster.sh

# Get worker nodes IPs
workers_ips=$(cat cluster_ips.txt | grep 'worker' | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' cluster_ips.txt)
for ip in $workers_ips; do
    echo "Requesting $ip to join.."
    scp join_cluster.sh root@${ip}:/home/vagrant
    sshpass -p 'root' ssh -o LogLevel=QUIET -o StrictHostKeyChecking=no -t root@${ip} /home/vagrant/join_cluster.sh
done
