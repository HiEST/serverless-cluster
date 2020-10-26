#!/bin/bash

function usage(){
    echo "Usage: ./copy_scripts.sh 'node_type'"
    echo " 'node_type'  the type of the node (master or worker)"
}

if [ $# -eq 1 ]
then
    value="$1"
    if [ $value == master ]
    then 
        vagrant scp ../cluster_ips.txt :cluster_ips.txt
        vagrant scp ../scripts/setup_env.sh :setup_env.sh
        vagrant scp ../scripts/setup_knative.sh :setup_knative.sh
        vagrant scp ../scripts/setup_ssh.sh :setup_ssh.sh
        vagrant scp ../storage_objs/persistentVolume.yaml :storage_objs/persistentVolume.yaml
        vagrant scp ../storage_objs/storageClass.yaml :storage_objs/storageClass.yaml
        vagrant scp ../samples/knative_hello.yaml :samples/knative_hello.yaml 
        vagrant scp ../samples/kafka_client.yaml :samples/kafka_client.yaml
    elif [ $value == worker ]
    then
        vagrant scp ../cluster_ips.txt :cluster_ips.txt
        vagrant scp ../scripts/setup_env.sh :setup_env.sh
    else
        usage
        exit
    fi
else
    echo "ERROR: You have to provide the node type!"
    usage
    exit
fi
