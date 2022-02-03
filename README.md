# Kubernetes VM-based Serverless Cluster 

The set of scripts configure a cluster of 11 Kubernetes (K8s) nodes: 1 master node (k8s-master) and 10 workers nodes (k8s-worker-node1 to k8s-worker-node10). The current cluster configuration does not allow to run jobs on the master node, it runs only the kubernetes control plane.

The cluster is built on 11 Ubuntu VMs, created with Vagrant, having the following characteristics:
- master node: 32 GB of memory, 16 CPUs and 50GB of storage
- worker node: 32 GB of memory, 8 CPUs and 50GB of storage

Each cluster node VM is placed on a different physical node, and the VMs IPs have to be set properly accordingly with the specific available network.<br />
To change the VMs resources and the associated IPs, change the associated Vagrant files. 
The hostnames and the related IPs have to be summerized in the cluster_ips.txt file.

## Requirements
* Virtualbox version: 6.1.12
* Vagrant version: 2.2.10
* Vagrant box: ubuntu/bionic64

## Technologies
The K8s serverless cluster has been created with:
* Docker version: 19.03.11 
* Kubernetes version: 1.19.3
* Knative serving version: 0.25.0
* Knative eventing version: 0.25.0
* Helm version: 3.3.4
* Istio version: 1.11.0
* Tekton version: 0.27.3

## Setup
To obtain your serverless K8s cluster perform the following steps:

### Vagrant
The Vagrant VMs are based on the 'ubuntu/bionic64' box, therefore if this specific box is not present, add it with the following command:
```
$ vagrant box add ubuntu/bionic64
```

Then, to start the cluster configuration, first ssh to each physical machine. In the current configuration, you will end up with 4 diffent terminals. Within these 4 terminals enter in the 4 different k8s nodes folders, namely k8s-master, k8s-worker-node1, k8s-worker-node2, k8s-worker-node3, and boot up the VMs:
```
$ vagrant up
```

Once the VMs are up and running, only inside the master VM create two folders: 'storage_objs' and 'samples'. Then, outside the VMs, run copy_scripts.sh from each of the 4 terminals:
```
$ ../scripts/copy_scripts.sh 'type_node'
```
where 'type_node' is either 'master' or 'worker'. 

Now the VMs are ready for the k8s installation.

### Kubernetes
First, setup Kubernetes on the 3 workers nodes by running the following command inside the VMs:
```
$ sudo ./setup_env.sh -type worker -name 'k8s_node_name' -ip 'VM_ip'
```
where 'k8s_node_name' is the custom k8s worker node name and 'VM_ip' is the IP present in the related worker Vagrantfile.
 
For example, in the current configuration the first worker node command is:
```
$ sudo ./setup_env.sh -type worker -name k8s-worker-node1 -ip 10.0.26.206
```

Then, similarly to what has been done for the workers nodes, setup and install Kubernets on the master node:
```
$ sudo ./setup_env.sh -type master -name 'k8s_node_name' -ip 'VM_ip'
```
where 'k8s_node_name' is the custom k8s master node name and 'VM_ip' is the IP present in the master Vagrantfile.

For example, in the current configuration the master node command is:
```
$ sudo ./setup_env.sh -type master -name k8s-master -ip 10.0.26.205
```

This last command generates a shell script, named 'join_cluster.sh'. This script is automatically copied over ssh to the workers home folder and contains the join command to be executed as root from each worker node to actually join the k8s cluster:
```
$ sudo ./join_cluser.sh
```
If the node has joined correctly the cluser, the following output should appear:
```
This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster. 
```

To double-check all the workers nodes have joined correctly the cluster run the following command from the master VM:
```
$ kubectl get nodes
NAME                STATUS   ROLES                  AGE   VERSION
k8s-master          Ready    control-plane,master   10d   v1.19.3
k8s-worker-node1    Ready    <none>                 10d   v1.19.3
k8s-worker-node10   Ready    <none>                 68m   v1.19.3
k8s-worker-node2    Ready    <none>                 10d   v1.19.3
k8s-worker-node3    Ready    <none>                 10d   v1.19.3
k8s-worker-node4    Ready    <none>                 69m   v1.19.3
k8s-worker-node5    Ready    <none>                 69m   v1.19.3
k8s-worker-node6    Ready    <none>                 69m   v1.19.3
k8s-worker-node7    Ready    <none>                 69m   v1.19.3
k8s-worker-node8    Ready    <none>                 69m   v1.19.3
k8s-worker-node9    Ready    <none>                 69m   v1.19.3
```
As shown, the 10 k8s worker nodes have actually joined the cluster. <br />
Optionally, the workers nodes role can be added by:
```
kubectl label node 'node_name' node-role.kubernetes.io/worker=worker
```
where 'node_name' is the value reported in the first column of the previous command output.
Running again the command:
```
$ kubectl get nodes
NAME                STATUS   ROLES                  AGE   VERSION
k8s-master          Ready    control-plane,master   10d   v1.19.3
k8s-worker-node1    Ready    worker                 10d   v1.19.3
k8s-worker-node10   Ready    worker                 68m   v1.19.3
k8s-worker-node2    Ready    worker                 10d   v1.19.3
k8s-worker-node3    Ready    worker                 10d   v1.19.3
k8s-worker-node4    Ready    worker                 69m   v1.19.3
k8s-worker-node5    Ready    worker                 69m   v1.19.3
k8s-worker-node6    Ready    worker                 69m   v1.19.3
k8s-worker-node7    Ready    worker                 69m   v1.19.3
k8s-worker-node8    Ready    worker                 69m   v1.19.3
k8s-worker-node9    Ready    worker                 69m   v1.19.3
```
should show the label 'worker' under the 'ROLES' column instead of the previous '`<none>`'.

At this point, Docker and Kubernetes have been installed and setup, along with all the necessary dependencies.

The pods deployed on the cluster should be something similar to:
```
$ kubectl get pods -o wide --all-namespaces 
NAMESPACE           NAME                                            READY       STATUS          RESTARTS        AGE     IP                  NODE                    NOMINATED NODE          READINESS GATES
istio-system        istio-ingressgateway-84cc7c44cc-qs57j           1/1         Running         0               10d     192.168.50.199      k8s-worker-node1        <none>                  <none>
istio-system        istiod-6b5df68ccb-vv69v                         1/1         Running         0               10d     192.168.50.198      k8s-worker-node1        <none>                  <none>
kafka               kafka-0                                         1/1         Running         8               10d     192.168.198.193     k8s-worker-node3        <none>                  <none>
kafka               kafka-1                                         1/1         Running         0               10d     192.168.50.200      k8s-worker-node1        <none>                  <none>
kafka               kafka-2                                         1/1         Running         0               10d     192.168.219.72      k8s-worker-node2        <none>                  <none>
kafka               kafka-zookeeper-0                               1/1         Running         0               10d     192.168.50.193      k8s-worker-node1        <none>                  <none>
kafka               kafka-zookeeper-1                               1/1         Running         0               10d     192.168.198.198     k8s-worker-node3        <none>                  <none>
kafka               kafka-zookeeper-2                               1/1         Running         0               10d     192.168.219.71      k8s-worker-node2        <none>                  <none>
knative-eventing    eventing-controller-5484fbcc45-v9dxt            1/1         Running         0               10d     192.168.198.203     k8s-worker-node3        <none>                  <none>
knative-eventing    eventing-webhook-867c7644b6-bxmqv               1/1         Running         0               10d     192.168.219.73      k8s-worker-node2        <none>                  <none>
knative-serving     activator-66ccff99f8-fdj9z                      1/1         Running         0               10d     192.168.219.65      k8s-worker-node2        <none>                  <none>
knative-serving     autoscaler-5dfd7d8bc6-4fqbr                     1/1         Running         0               10d     192.168.198.194     k8s-worker-node3        <none>                  <none>
knative-serving     controller-79f444b898-d72sk                     1/1         Running         0               10d     192.168.50.194      k8s-worker-node1        <none>                  <none>
knative-serving     domain-mapping-586dfb4787-fn2nn                 1/1         Running         0               10d     192.168.50.195      k8s-worker-node1        <none>                  <none>
knative-serving     domainmapping-webhook-65dd85b5b8-z6xg2          1/1         Running         0               10d     192.168.219.66      k8s-worker-node2        <none>                  <none>
knative-serving     net-istio-controller-987c8b9dd-8h8sx            1/1         Running         0               10d     192.168.198.201     k8s-worker-node3        <none>                  <none>
knative-serving     net-istio-webhook-69fbbd8d49-c9lzb              1/1         Running         0               10d     192.168.198.202     k8s-worker-node3        <none>                  <none>
knative-serving     webhook-854f698d87-xkqrw                        1/1         Running         0               10d     192.168.198.195     k8s-worker-node3        <none>                  <none>
kube-system         calico-kube-controllers-6dc98bc7cb-msxv2        1/1         Running         0               10d     192.168.235.194     k8s-master              <none>                  <none>
kube-system         calico-node-7rjrm                               1/1         Running         0               35m     10.0.26.213         k8s-worker-node4        <none>                  <none>
kube-system         calico-node-8qjz2                               1/1         Running         0               10d     10.0.26.207         k8s-worker-node2        <none>                  <none>
kube-system         calico-node-f9ht8                               1/1         Running         0               35m     10.0.26.214         k8s-worker-node5        <none>                  <none>
kube-system         calico-node-gfxgf                               1/1         Running         0               34m     10.0.26.219         k8s-worker-node10       <none>                  <none>
kube-system         calico-node-kv2fv                               1/1         Running         0               34m     10.0.26.217         k8s-worker-node8        <none>                  <none>  
kube-system         calico-node-pmlfd                               1/1         Running         0               10d     10.0.26.205         k8s-master              <none>                  <none>
kube-system         calico-node-rqjx7                               1/1         Running         0               10d     10.0.26.206         k8s-worker-node1        <none>                  <none>
kube-system         calico-node-rrl2k                               1/1         Running         0               10d     10.0.26.208         k8s-worker-node3        <none>                  <none>
kube-system         calico-node-v9jjr                               1/1         Running         0               34m     10.0.26.216         k8s-worker-node7        <none>                  <none>
kube-system         calico-node-wq6w8                               1/1         Running         0               34m     10.0.26.218         k8s-worker-node9        <none>                  <none>
kube-system         calico-node-zbf6h                               1/1         Running         0               34m     10.0.26.215         k8s-worker-node6        <none>                  <none>
kube-system         coredns-74ff55c5b-qq5bf                         1/1         Running         0               8d      192.168.198.215     k8s-worker-node3        <none>                  <none>
kube-system         coredns-74ff55c5b-xth9f                         1/1         Running         0               8d      192.168.50.255      k8s-worker-node1        <none>                  <none>
kube-system         etcd-k8s-master                                 1/1         Running         0               8d      10.0.26.205         k8s-master              <none>                  <none>
kube-system         kube-apiserver-k8s-master                       1/1         Running         0               8d      10.0.26.205         k8s-master              <none>                  <none>
kube-system         kube-controller-manager-k8s-master              1/1         Running         0               8d      10.0.26.205         k8s-master              <none>                  <none>
kube-system         kube-proxy-7vm8h                                1/1         Running         0               34m     10.0.26.216         k8s-worker-node7        <none>                  <none>
kube-system         kube-proxy-9gmrg                                1/1         Running         0               34m     10.0.26.217         k8s-worker-node8        <none>                  <none>
kube-system         kube-proxy-bn4nl                                1/1         Running         0               8d      10.0.26.208         k8s-worker-node3        <none>                  <none>
kube-system         kube-proxy-dt2tg                                1/1         Running         0               8d      10.0.26.206         k8s-worker-node1        <none>                  <none>
kube-system         kube-proxy-hgc74                                1/1         Running         0               35m     10.0.26.213         k8s-worker-node4        <none>                  <none>
kube-system         kube-proxy-hzhd4                                1/1         Running         0               8d      10.0.26.207         k8s-worker-node2        <none>                  <none>
kube-system         kube-proxy-kbhbm                                1/1         Running         0               34m     10.0.26.219         k8s-worker-node10       <none>                  <none>
kube-system         kube-proxy-scm7j                                1/1         Running         0               35m     10.0.26.214         k8s-worker-node5        <none>                  <none>
kube-system         kube-proxy-t9bqd                                1/1         Running         0               34m     10.0.26.218         k8s-worker-node9        <none>                  <none>
kube-system         kube-proxy-wn2hr                                1/1         Running         0               34m     10.0.26.215         k8s-worker-node6        <none>                  <none>
kube-system         kube-proxy-z2l9l                                1/1         Running         0               8d      10.0.26.205         k8s-master              <none>                  <none>
kube-system         kube-scheduler-k8s-master                       1/1         Running         0               8d      10.0.26.205         k8s-master              <none>                  <none>
tekton-pipelines    tekton-pipelines-controller-6675bc4ff6-z4tf7    1/1         Running         0               49m     192.168.219.95      k8s-worker-node2        <none>                  <none>
tekton-pipelines    tekton-pipelines-webhook-6f449dbcbb-4wfx9       1/1         Running         0               88m     192.168.198.218     k8s-worker-node3        <none>                  <none>
```

### Knative 
On top of Kubernetes, the serverless abstraction Knative has to be installed and setup.

Along with Knative, other core components are going to be installed, such as the Istio service mesh and the Apache Kafka message distributed streaming platform.
In particular, Kafka can be configured to use either ephemeral storage or persistent storage. 
To install Knative with Kafka exploiting ephemeral storage run in the master VM the following command:
```
$ ./setup_knative.sh -type ephem
```
or, alternatively:
```
$ ./setup_knative.sh -kafka pers -vol 'dimension'
```
where 'dimension' is the dimension in GB of the volume attached to each Kafka broker. Pay attention that this dimension should never exceed the total storage available in the corresponding VM.

To finalize the Knative setup, reload the .bashrc settings:
```
source ~/.bashrc
```

For the persistent configuration, check that the following pods have been deployed:
```
$ kubectl get pods --namespace kafka
NAME                READY   STATUS    RESTARTS   AGE
kafka-0             1/1     Running   1          8m20s
kafka-1             1/1     Running   0          6m26s
kafka-2             1/1     Running   0          5m34s
kafka-zookeeper-0   1/1     Running   0          8m20s
kafka-zookeeper-1   1/1     Running   0          7m24s
kafka-zookeeper-2   1/1     Running   0          6m44s
```
Then, check that the PVCs are actually bind to the automatically created PVs. First check that the PVs have been created:
```
$ kubectl get pv --namespace kafka
NAME                   CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS          REASON   AGE
node1-kafka-local-pv   10Gi       RWO            Retain           Bound    kafka/datadir-kafka-0   kafka-local-storage            11m
node2-kafka-local-pv   10Gi       RWO            Retain           Bound    kafka/datadir-kafka-1   kafka-local-storage            11m
node3-kafka-local-pv   10Gi       RWO            Retain           Bound    kafka/datadir-kafka-2   kafka-local-storage            11m
```
As the command output reports, the 3 volumes are bounded to the PVCs shown in the column 'CLAIM'.
A similar outcome should be reported also from PVCs command:
```
$ kubectl get pvc --namespace kafka 
NAME              STATUS   VOLUME                 CAPACITY   ACCESS MODES   STORAGECLASS          AGE
datadir-kafka-0   Bound    node1-kafka-local-pv   10Gi       RWO            kafka-local-storage   11m
datadir-kafka-1   Bound    node2-kafka-local-pv   10Gi       RWO            kafka-local-storage   9m8s
datadir-kafka-2   Bound    node3-kafka-local-pv   10Gi       RWO            kafka-local-storage   8m16s
```
indeed, the command output shows the correct binding between PVCs and PVs represented by the 'Bound' status of each PVC.

Now you are ready to run the samples, to check if everything has been installed and setup correctly.

