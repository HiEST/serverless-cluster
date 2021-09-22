# Samples
The reported samples allow to check if the installation and setup phases have been correctly executed.

## Knative Helloworld service
First, deploy the helloworld service.
```
$ kubectl apply --filename knative_hello.yaml
service.serving.knative.dev/helloworld-go created
```

Check if the app has been deployed successfully (it can take some seconds).
```
$ kn service describe helloworld-go
Name:       helloworld-go
Namespace:  default 
Age:        1m
URL:        http://helloworld-go.default.example.com            

Revisions: 
     100%  @latest (helloworld-go-r4phm) [1] (1m)
                 Image:  gcr.io/knative-samples/helloworld-go (at 5ea96b)  

Conditions: 
     OK TYPE                   AGE REASON
     ++ Ready                  2m
     ++ ConfigurationsReady    2m
     ++ RoutesReady            2m
```
In the command output, when the symbols '++' appear in the OK column, means that the service is up and ready to receive requests.

Send a request to the service:
``` 
$ curl -H "Host: helloworld-go.default.example.com"  "http://$GATEWAY_URL/" -v
*   Trying 10.0.26.207...
* TCP_NODELAY set
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0* Connected to 10.0.26.207 (10.0.26.207) port 30177 (#0)
> GET / HTTP/1.1 
> Host: helloworld-go.default.example.com
> User-Agent: curl/7.58.0
> Accept: */* 
>
  0     0    0     0    0     0      0      0 --:--:--  0:00:07 --:--:--     0< HTTP/1.1 200 OK
< content-length: 20
< content-type: text/plain; charset=utf-8
< date: Fri, 23 Oct 2020 12:45:10 GMT
< server: istio-envoy
< x-envoy-upstream-service-time: 7798
<
{ [20 bytes data] 
100    20  100    20    0     0      2      0  0:00:10  0:00:07  0:00:03     5
* Connection #0 to host 10.0.26.207 left intact
``` 
where $GATEWAY_URL is the Istio gateway.

In case the environment is setup correctly, you should see the service 'Hello Go Sample v1! ' message. 

Finally, remove the service to leave the environment clean:
```
$ kn service delete helloworld-go
Service 'helloworld-go' successfully deleted in namespace 'default'.
```

## Kafka channel sample
Deploy the kafka client that will help us put and get messages from topics:
```
$ kubectl apply --namespace kafka --filename kafka_client.yaml
pod/testclient created
```

Create a topic "message" with one partition and replication factor '1'.
```
$ cd ../kafka 
$ kubectl --namespace kafka exec -it testclient -- ./bin/kafka-topics.sh --zookeeper kafka-zookeeper:2181 --topic messages --create --partitions 1 --replication-factor 1
Created topic "messages".
```

In the current shell terminal create a producer that will publish messages to the topic:
```
$ kubectl  --namespace kafka exec -ti testclient -- ./bin/kafka-console-producer.sh --broker-list kafka:9092 --topic messages
>
```

Open another shell terminal in the master VM, and from the kafka folder create a consumer session:
```
$ kubectl --namespace kafka exec -ti testclient -- ./bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic messages
```

Then, try to write a message on the producer session. The same messages should appear in the consumer session.

Finally, once the kafka configuration has been tested remove the created topic to leave the environment clean.
```
$ kubectl --namespace kafka exec -it testclient -- ./bin/kafka-topics.sh --zookeeper kafka-zookeeper:2181 --delete --topic messages
Topic messages is marked for deletion.
Note: This will have no impact if delete.topic.enable is not set to true.
```

## Tekton samples
Within Tekton, you have the choise to use either channels or workspaces for the data exchange among functions. With channels the maximum dimension for the single message is of 4KB. To overcome this limit, usually Persistent Volume Claims (PVCs) are used in the Workspace as Volume Source.<br /> 
For this reason we have reported two samples, testing the two different options.

### Tekton with channels
The pipeline inputs are represented by two parameters, namely a and b, assuming the values of 2 and 10 respectively.<br />
The pipeline is composed of three stages. In the first stage the sum and multiply operations are performed concurrently. Then, in the second stage, their outputs are concatenaded to form a single value. In the third and last stage, this concatenated value is sum with itself to create the final pipeline output.

From the samples directory, to create the sample pipeline run the following command:
```
$ kubectl create -f tekton_sum_and_multiply.yaml
pipeline.tekton.dev/sum-and-multiply-pipeline created
task.tekton.dev/sum created
task.tekton.dev/multiply created 
pipelinerun.tekton.dev/sum-and-multiply-pipeline-run-56g47 created
```

The execution of the pipeline starts at creation. To check the results of our pipeline, read the generate logs:
```
$ tkn pipelinerun logs sum-and-multiply-pipeline-run-56g47 -f
[sum-inputs : sum] 12

[multiply-inputs : product] 20

[sum-and-multiply : sum] 4024

[sum-inputs : istio-proxy] 2020/10/29 10:20:54 Exiting...  

[multiply-inputs : istio-proxy] 2020/10/29 10:20:54 Exiting...

[sum-and-multiply : istio-proxy] 2020/10/29 10:21:25 Exiting...
```

The pipeline execution returns the sum and multiply results, 12 and 20 respectively, and the final pipeline output of 4024.

To leave the environment clean, remove the deployed resources:
```
$ kubectl delete tasks --all
task.tekton.dev "multiply" deleted
task.tekton.dev "sum" deleted

$ kubectl delete pipelines --all
pipeline.tekton.dev "sum-and-multiply-pipeline" deleted

$ kubectl delete pipelineruns --all
pipelinerun.tekton.dev "sum-and-multiply-pipeline-run-56g47" deleted
```

### Tekton with PVC Volume Source
The pipeline is composed by two stages: the first creates an array of 5000 elements and writes it on a file, namely file.txt, while the second stage reads the content of the file and stores it in an array. <br />
The file is first written and then read from a shared workspace represented by a Local Persistent Volume.

Before creating the pipeline, we need to create the volume folder on one of the cluster nodes and then to deploy the volume. For this specific sample, k8s-worker-node1 has been used. Enter in the VM and create the volume folder:
```
sudo mkdir -p /mnt/disk/vol2
```
By modifing the persistentVolumeTekton.yaml file, you can modify the volume path by changing the 'local' field, as well as the node where to place the volume by changing the nodeSelectorTerms's values field.

Then, deploy the Kubernetes volume resource with the following command:
```
$ kubectl apply -f ../storage_objs/persistentVolumeTekton.yaml
persistentvolume/tekton-local-pv created
```

Only now we can create the pipeline:
```
$ kubectl create -f tekton_array_with_workspace.yaml
pipeline.tekton.dev/array-pvc-pipeline created
task.tekton.dev/write created
task.tekton.dev/read created
pipelinerun.tekton.dev/array-pvc-pipeline-run-2j77w created
```

Inspecting the pipeline's logs we can see the output of its run:
```
$ tkn pipelinerun logs array-pvc-pipeline-run-2j77w -f
[write-file : write] WRITER: written numbers from 1 to 5000 to file.txt
[read-file : read] READER: read file.txt of dimension 23893 B containing an array of 5000 elements!

[write-file : istio-proxy] 2020/10/29 14:02:52 Exiting...

[read-file : istio-proxy] 2020/10/29 14:02:55 Exiting..
```

As the command output shows, the writer has written the array on the file and the reader is capable to read it successfully.

Finally, delete all the deployed resource to leave the environment clean:
```
$ kubectl delete pipelinerun array-pvc-pipeline-run-2j77w
pipelinerun.tekton.dev "array-pvc-pipeline-run-2j77w" deleted

$ kubectl delete pipeline array-pvc-pipeline
pipeline.tekton.dev "array-pvc-pipeline" deleted

$ kubectl delete task write
task.tekton.dev "write" deleted

$ kubectl delete task read
task.tekton.dev "read" deleted

$ kubectl delete pv tekton-local-pv
persistentvolume "tekton-local-pv" deleted
```
