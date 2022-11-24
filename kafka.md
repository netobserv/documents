# Deploy Kafka on Openshift using Strimzi Operator

The easiest way to deploy Kafka on Openshift is using [Strimzi](https://strimzi.io/).
An Operator is available in OperatorHub section.
Simply install it and create a "Kafka" instance in `default` namespace.

## Manual installation of strimzi operator

You can use the following command to deploy the strimzi operator :

```bash
export NAMESPACE=netobserv
kubectl create -f "https://strimzi.io/install/latest?namespace=$NAMESPACE" -n $NAMESPACE
```
## Update storage class of kafka cluster

```bash
export DEFAULT_SC=$(kubectl get storageclass -o=jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
tmpfile=$(mktemp)
envsubst < ./examples/kafka/default.yaml > $tmpfile && mv $tmpfile ./examples/kafka/default.yaml
```

## Creating the default cluster

A simple Kafka resource, with ephemeral storage and metrics enabled, can be found [here](./examples/kafka/default.yaml).

```bash
kubectl apply -f ./examples/kafka/metrics-config.yaml -n $NAMESPACE
kubectl apply -f ./examples/kafka/default.yaml -n $NAMESPACE
```

For metrics, a ServiceMonitor resource is provided, so you will need a Prometheus operator installed and able to fetch it.

### mTLS

Alternatively, a secure setup with enforced mutual-TLS is provided:

```bash
kubectl apply -f ./examples/kafka/metrics-config.yaml -n $NAMESPACE
kubectl apply -f ./examples/kafka/tls.yaml -n $NAMESPACE
```

## Creating a topic

Topics can be managed through the strimzi operator. An example of kafka-topic.yaml can be found [here](./examples/kafka/topic.yaml).

```bash
kubectl apply -f ./examples/kafka/topic.yaml -n $NAMESPACE
```

## Creating a user

Creating one or several users is necessary for mTLS.

```bash
kubectl apply -f ./examples/kafka/user.yaml -n $NAMESPACE
kubectl wait --timeout=180s --for=condition=ready kafkauser flp-kafka -n $NAMESPACE
```

When using mTLS, you should wait that the `KafkaUser` resource is ready (meaning: processed by Strimzi user operator) before deploying flowlog-pipeline or the eBPF agent, because they need to mount the generated secret files. Otherwise, the pods are stuck, you would need to delete them in order to restart them.

## Deleting user, topic and cluster

```bash
kubectl delete -f ./examples/kafka/user.yaml -n $NAMESPACE
kubectl delete -f ./examples/kafka/topic.yaml -n $NAMESPACE
kubectl delete kafka kafka-cluster -n $NAMESPACE
kubectl delete -f ./examples/kafka/metrics-config.yaml -n $NAMESPACE
```

## Tooling

You can use [kfk](https://github.com/systemcraftsman/strimzi-kafka-cli), a CLI for Kafka / Strimzi, to interact with the cluster. Examples:

### Listening to the exporter topic

Create a topic for export, e.g. `netobserv-flows-export`:

```bash
kubectl apply -f ./examples/kafka/topic-export.yaml
kfk topics --cluster kafka-cluster -n netobserv  --list
```

will display something like:

```
NAME                                                                                               CLUSTER         PARTITIONS   REPLICATION FACTOR   READY
consumer-offsets---84e7a678d08f4bd226872e5cdd4eb527fadc1c6a                                        kafka-cluster   50           1                    True
netobserv-flows-export                                                                             kafka-cluster   24           1                    True
network-flows                                                                                      kafka-cluster   24           1                    True
strimzi-store-topic---effb8e3e057afce1ecf67c3f5d8e4e3ff177fc55                                     kafka-cluster   1            1                    True
strimzi-topic-operator-kstreams-topic-store-changelog---b75e702040b99be8a9263134de3507fc0cc4017b   kafka-cluster   1            1                    True
```

In `FlowCollector` resource, configure the exporter accordingly:

```yaml
  exporters:
    - type: KAFKA
      kafka:
        address: "kafka-cluster-kafka-bootstrap.netobserv"
        topic: netobserv-flows-export
```

Connect to the topic as a consummer, using `kfk console-consumer`:

```bash
kfk console-consumer --topic netobserv-flows-export -n netobserv -c kafka-cluster
```

You should soon see the enriched flows coming in, as json:

```json
{"Bytes":66,"DstAddr":"10.0.181.113","DstK8S_Name":"ip-10-0-181-113.eu-west-1.compute.internal","DstK8S_Namespace":"","DstK8S_OwnerName":"ip-10-0-181-113.eu-west-1.compute.internal","DstK8S_OwnerType":"Node","DstK8S_Type":"Node","DstMac":"06:70:08:FF:88:53","DstPort":6443,"Etype":2048,"FlowDirection":0,"Interface":"br-ex","Packets":1,"Proto":6,"SrcAddr":"10.0.176.217","SrcMac":"06:A5:38:0F:E1:E9","SrcPort":15467,"TimeFlowEndMs":1666602825831,"TimeFlowStartMs":1666602825831,"TimeReceived":1666602829}
{"Bytes":6897,"DstAddr":"10.131.0.11","DstK8S_HostIP":"10.0.143.168","DstK8S_HostName":"ip-10-0-143-168.eu-west-1.compute.internal","DstK8S_Name":"prometheus-k8s-0","DstK8S_Namespace":"openshift-monitoring","DstK8S_OwnerName":"prometheus-k8s","DstK8S_OwnerType":"StatefulSet","DstK8S_Type":"Pod","DstMac":"0A:58:0A:80:00:01","DstPort":53598,"Etype":2048,"FlowDirection":0,"Interface":"8dda2b5704fb105","Packets":2,"Proto":6,"SrcAddr":"10.128.0.18","SrcK8S_HostIP":"10.0.181.113","SrcK8S_HostName":"ip-10-0-181-113.eu-west-1.compute.internal","SrcK8S_Name":"cloud-credential-operator-75f8d887bd-lmrcv","SrcK8S_Namespace":"openshift-cloud-credential-operator","SrcK8S_OwnerName":"cloud-credential-operator","SrcK8S_OwnerType":"Deployment","SrcK8S_Type":"Pod","SrcMac":"0A:58:0A:80:00:12","SrcPort":8443,"TimeFlowEndMs":1666602824686,"TimeFlowStartMs":1666602824686,"TimeReceived":1666602829}
{"Bytes":872,"DstAddr":"10.0.206.183","DstMac":"06:A0:24:AD:72:1B","DstPort":19026,"Etype":2048,"FlowDirection":1,"Interface":"br-ex","Packets":1,"Proto":6,"SrcAddr":"10.0.181.113","SrcK8S_Name":"ip-10-0-181-113.eu-west-1.compute.internal","SrcK8S_Namespace":"","SrcK8S_OwnerName":"ip-10-0-181-113.eu-west-1.compute.internal","SrcK8S_OwnerType":"Node","SrcK8S_Type":"Node","SrcMac":"06:70:08:FF:88:53","SrcPort":6443,"TimeFlowEndMs":1666602824972,"TimeFlowStartMs":1666602824972,"TimeReceived":1666602829}
```

### TLS management

To create a new user with public/private keys for mTLS, and get its secrets:

```bash
kfk users --create --user flp-kafka --authentication-type tls -n netobserv -c kafka-cluster
kubectl describe secret/flp-kafka -n netobserv
```

To create a terminal-based producer and consumer with mTLS, refer to [this page](https://github.com/systemcraftsman/strimzi-kafka-cli/tree/main/examples/2_tls_authentication).



# Web UI for Kafka using Kowl
Check [kowl.yaml](examples/kowl.yaml) file and update broker URL and extraVolumes if needed.

Then run the following commands to create a Kowl instance:

```bash
helm repo add cloudhut https://raw.githubusercontent.com/cloudhut/charts/master/archives
helm repo update
helm upgrade --install -f examples/kowl.yaml kowl cloudhut/kowl
```

You should get a prompt showing status `deployed`

Then run:

```bash
kubectl port-forward svc/kowl 8080:80
```

Open `http://127.0.0.1:8080` to access kowl.
