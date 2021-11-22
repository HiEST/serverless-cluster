#!/bin/bash

function usage(){
    echo "Usage: ./copy_scripts.sh -role 'node_role' [-test 'test_type']"
    echo "  -role  'node_role'      specify the node role (master, worker or nfsserver)"
    echo "  -test  'test_type'      specify the test type (local_mem, local_disk or remote_nfs)"
}

# Check if the node type is given
if [ $# -lt 2 ]
then
    echo "ERROR: you have to provide the node role!"
    usage
    exit 1
else
    while [[ $# -gt 0 ]]
    do
        key=$1
        case $key in
            -role) NODE_ROLE=$2
                if [ $NODE_ROLE != master -a $NODE_ROLE != worker -a $NODE_ROLE != nfsserver]
                then
                    echo "ERROR: illegal argument for key -role!"
                    usage
                    exit 1
                fi
                ROLE_GIVEN=1
                shift
                ;;
            -test) TEST_TYPE=$2
                if [ $TEST_TYPE != local_mem -a $TEST_TYPE != local_disk -a $TEST_TYPE != remote_nfs ]
                then
                     echo "ERROR: illegal argument for key -test!"
                     usage
                     exit 1
                fi
                TEST_GIVEN=1
                shift
                ;;
            *) echo "ERROR: illegal argument key $key!"
                usage
                exit 1
                ;;
        esac
        shift
    done
fi

if [ ! $ROLE_GIVEN ] 
then
    echo "ERROR: The role parameter is mandatory!"
    usage
    exit 1
fi

# Vim configuration
vagrant scp $HOME/.vimrc .vimrc
vagrant scp $HOME/.vim .vim

# Git repo private key
vagrant scp $HOME/.ssh/id_rsa_git id_rsa_git

# Cluster IPs
vagrant scp ../cluster_ips.txt cluster_ips.txt

if [ $NODE_ROLE == master ]
then
    # Cluster files
    vagrant scp ../scripts/setup_env.sh setup_env.sh
    vagrant scp ../scripts/setup_knative.sh setup_knative.sh
    vagrant scp ../scripts/setup_ssh.sh setup_ssh.sh
    vagrant scp ../samples/knative_hello.yaml samples/knative_hello.yaml 
    vagrant scp ../samples/kafka_client.yaml samples/kafka_client.yaml
    vagrant scp ../samples/tekton_sum_and_multiply.yaml samples/tekton_sum_and_multiply.yaml
    vagrant scp ../samples/tekton_array_with_workspace.yaml samples/tekton_array_with_workspace.yaml
    vagrant scp ../storage_objs/persistentVolume.yaml storage_objs/persistentVolume.yaml
    vagrant scp ../storage_objs/persistentVolumeTekton.yaml storage_objs/persistentVolumeTekton.yaml
    vagrant scp ../storage_objs/storageClass.yaml storage_objs/storageClass.yaml
    if [ $TEST_GIVEN ]
    then
        if [ $TEST_TYPE == local_disk ] 
        then
            vagrant scp ../storage_objs/persistentVolumeTektonVol.yaml storage_objs/pv.yaml
        elif [ $TEST_TYPE == remote_nfs ]
        then
            vagrant scp ../storage_objs/persistentVolumeTektonNFS.yaml storage_objs/persistentVolumeTektonNFS.yaml
        fi
    fi
elif [ $NODE_ROLE == worker ]
then
    vagrant scp ../scripts/setup_env.sh setup_env.sh
elif [ $NODE_ROLE == nfsserver ]
    vagrant scp ../scripts/setup_nfs_server.sh setup_nfs_server.sh
else
    echo "ERROR: You have to provide the node type!"
    usage
    exit
fi

