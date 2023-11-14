## Setup ACM with NetObserv metrics

Quick guide:

1. Create 2 clusters
2. On main: install ACM operator; Create a default MultiClusterHub
3. In console top bar, select "all cluster" then start procedure to import an existing cluster
4. Install netobserv downstream (user workload prometheus won't work) + Create a FlowCollector

cf steps at https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.8/html/observability/observing-environments-intro#enabling-observability :

```bash
oc create namespace open-cluster-management-observability
DOCKER_CONFIG_JSON=`oc extract secret/pull-secret -n openshift-config --to=-`
oc create secret generic multiclusterhub-operator-pull-secret \
    -n open-cluster-management-observability \
    --from-literal=.dockerconfigjson="$DOCKER_CONFIG_JSON" \
    --type=kubernetes.io/dockerconfigjson
```

Setup S3, Thanos Secret and ACM observability:

```bash
./thanos-s3.sh yourname-thanos us-east-2
oc apply -f acm-observability.yaml 
```

Enable metrics:
In `spec.processor.metrics.includeList`, set:
- `workload_egress_bytes_total`
- `workload_egress_packets_total`
- `workload_ingress_packets_total`



oc apply -f netobserv-metrics.yaml 

To debug the above config, check logs here:

```bash
oc logs -n open-cluster-management-addon-observability -l component=metrics-collector
```

Metrics resolution = 5 minutes

Designing dashboards: https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.8/html/observability/using-grafana-dashboards#setting-up-the-grafana-developer-instance
