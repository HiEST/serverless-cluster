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
