#!/bin/bash
function usage(){
    echo "Usage: ./setup_knative.sh -kafka 'channel_conf' [-vol 'dimension']"
    echo "  -kafka  'channel_conf'      specify channel configuration (ephem or pers)"
    echo "  -vol    'dimension'         specify kafka volumes dimension [GiB] in persistent configuration"
}

# Check if the kakva configuration is given
if [ $# -lt 2 ]
then
    echo "ERROR: you have to provide the kafka configuration type!"
    usage
    exit 1
else
    key="$1"
    if [ $key == -kafka ]
    then
        KAFKA_CONF=$2
        shift
        if [ $KAFKA_CONF != ephem -a $KAFKA_CONF != pers ]
        then
            echo "ERROR: illegal argument for key -kafka!"
            usage
            exit 1
        else
            shift
            if [ $KAFKA_CONF == pers ]
            then 
                if [ $# -eq 0 ]
                then
                    echo "ERROR: when persistent configuration is set, you have to define the kafka volumes dimension!"
                    usage
                    exit 1
                else
                    key=$1
                    if [ $key == -vol ]
                    then
                        VOL_DIM=$2
                    else
                        echo "ERROR: illegal argument key!"
                        usage
                        exit 1
                    fi
                fi
            fi
        fi
    else
        echo "ERROR: illegal argument key $key!"
        usage
        exit 1
    fi
fi

# Create kafka namespace
kubectl create namespace kafka

# Install Helm k8s packet manager
wget https://get.helm.sh/helm-v3.3.4-linux-amd64.tar.gz
tar -zxvf helm-v3.3.4-linux-amd64.tar.gz
rm -rf helm-v3.3.4-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm 
rm -rf linux-amd64

# Install Kafka using Helm chart
helm repo add incubator https://charts.helm.sh/incubator
curl https://raw.githubusercontent.com/helm/charts/master/incubator/kafka/values.yaml > values.yaml
replicas_line_num=$(grep -n -m 1 replicas: values.yaml | sed  's/\([0-9]*\).*/\1/')
workers=( $(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' cluster_ips.txt | sed -n -e '2,4p') )
num_workers=$(echo "${#workers[@]}")
sed -i ''"${replicas_line_num}"'s/replicas: 3/replicas: '"${num_workers}"'/' values.yaml

if [ $KAFKA_CONF == ephem ]
then
    # Setup ephemeral channel configuration
    pers_line_num=$(grep -n -m 1 persistence: values.yaml |sed  's/\([0-9]*\).*/\1/')
    enable_line_num=$((pers_line_num+1))
    sed -i ''"${enable_line_num}"'s/enabled: true/enabled: false/' values.yaml
else
    # Setup persistent channel configuration
    size_line_num=$(grep -n -m 1 size: values.yaml |sed  's/\([0-9]*\).*/\1/')
    sed -i ''"${size_line_num}"'s/size: "1Gi"/size: "'"$VOL_DIM"'Gi"/' values.yaml
    storage_line_num=$(grep -n -m 1 "# storageClass:" values.yaml | sed  's/\([0-9]*\).*/\1/')
    sed -i ''"${storage_line_num}"'s/# storageClass:/storageClass: kafka-local-storage/' values.yaml
    counter=1
    for ip in "${workers[@]}"
    do
        # Create persistent volumes mount path on workers
        sudo ssh root@$ip mkdir -p /mnt/disk/vol1 
        # Create k8s persistent volume
        cp storage_objs/persistentVolume.yaml storage_objs/pv.yaml
        sed -i 's/node-kafka-local-pv/node'"$counter"'-kafka-local-pv/' storage_objs/pv.yaml 
        sed -i 's/10Gi/'"$VOL_DIM"'Gi/' storage_objs/pv.yaml 
        sed -i 's/k8s-worker-node/k8s-worker-node'"${counter}"'/' storage_objs/pv.yaml 
        kubectl apply -f storage_objs/pv.yaml
        rm storage_objs/pv.yaml
	counter=$((counter+1))
    done
    # Create kafka storage class
    kubectl apply -f storage_objs/storageClass.yaml
fi

helm install kafka incubator/kafka -n kafka -f values.yaml
rm values.yaml

# Downlaod the kafka source code
#wget https://ftp.cixug.es/apache/kafka/2.7.0/kafka-2.7.0-src.tgz
#tar -zxvf kafka-2.7.0-src.tgz
#mv kafka-2.7.0-src kafka
#rm kafka-2.7.0-src.tgz

# Install Knative Serving component
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.18.0/serving-crds.yaml
kubectl apply --filename https://github.com/knative/serving/releases/download/v0.18.0/serving-core.yaml

# Download, install and configure Istio (default configuration profile)
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.7.3 sh -
sudo mv istio-1.7.3/bin/istioctl /usr/local/bin/
rm -rf istio-1.7.3
istioctl install --set values.global.imagePullPolicy=IfNotPresent -y
kubectl label namespace default istio-injection=enabled
cat <<EOF | kubectl apply -f -
apiVersion: "security.istio.io/v1beta1"
kind: "PeerAuthentication"
metadata:
  name: "default"
  namespace: "knative-serving"
spec:
  mtls:
    mode: PERMISSIVE
EOF

# Install Knative KIngress controller for Istio
kubectl apply --filename https://github.com/knative/net-istio/releases/download/v0.18.0/release.yaml

# Set service's node ports to access the gateway (no external load balancer)
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
echo "export INGRESS_PORT=$INGRESS_PORT" >> ~/.bashrc 
SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "export SECURE_INGRESS_PORT=$SECURE_INGRESS_PORT" >> ~/.bashrc 
#TCP_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="tcp")].nodePort}')
#echo "export TCP_INGRESS_PORT=$TCP_INGRESS_PORT" >> ~/.bashrc 
INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}')
echo "export INGRESS_HOST=$INGRESS_HOST" >> ~/.bashrc 
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
echo "export GATEWAY_URL=$GATEWAY_URL" >> ~/.bashrc
source ~/.bashrc

# Install Knative Eventing component
kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.18.0/eventing-crds.yaml
kubectl apply --filename https://github.com/knative/eventing/releases/download/v0.18.0/eventing-core.yaml

# Istall Knative CLI
wget https://storage.googleapis.com/knative-nightly/client/latest/kn-linux-amd64
mv kn-linux-amd64 kn
chmod 711 kn
sudo mv kn /usr/local/bin

# Install Tekton Pipelines
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Install Tekton CLI
curl -LO https://github.com/tektoncd/cli/releases/download/v0.13.1/tkn_0.13.1_Linux_x86_64.tar.gz
sudo tar xvzf tkn_0.13.1_Linux_x86_64.tar.gz -C /usr/local/bin/ tkn
rm -rf tkn_0.13.1_Linux_x86_64.tar.gz
