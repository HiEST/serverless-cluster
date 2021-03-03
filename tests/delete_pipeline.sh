# Delete pipelinerun
#kubectl delete pipelinerun --all

# Delete pipeline
#kubectl delete pipeline write-read-array-pipeline 2> /dev/null

# Delete task in memory volume conf
#kubectl delete task read-write 2> /dev/null  

# Delete tasks in local volume and NFS volume confs
#kubectl delete tasks write read 2> /dev/null

# Delete local volume
#kubectl delete pv tekton-local-pv 2> /dev/null

# Delete NFS volume
#kubectl delete pv tekton-nfs-pv 2> /dev/null
