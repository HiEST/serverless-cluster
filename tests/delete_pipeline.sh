kubectl delete pipelinerun --all

kubectl delete pipeline write-read-array-pipeline 2> /dev/null
kubectl delete tasks write read 2> /dev/null

#Local Volume
kubectl delete pv tekton-local-pv 2> /dev/null

#NFS Volume
kubectl delete pv tekton-nfs-pv 2> /dev/null
