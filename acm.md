## Setup ACM with NetObserv metrics

cf also [blog post](./blogs/acm/leverage-metrics-in-acm.md).

This is more a quick guide for the development teams.

Quick guide:

1. Create 2 clusters (or more)
2. Choose one for being the main one / hub: install ACM operator on it; Create a default MultiClusterHub
3. In console top bar, select "all cluster" then start procedure to import an existing cluster

On each cluster:
1. Install netobserv downstream (user workload prometheus won't work)
2. Create a FlowCollector, with these metrics enabled (`spec.processor.metrics.includeList`) :

```yaml
      includeList:
        - namespace_flows_total
        - node_ingress_bytes_total
        - workload_ingress_bytes_total
        - workload_egress_bytes_total
        - workload_egress_packets_total
        - workload_ingress_packets_total
```

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
./examples/ACM/thanos-s3.sh yourname-thanos us-east-2
oc apply -f examples/ACM/acm-observability.yaml
oc get pods -n open-cluster-management-observability -w
oc apply -f examples/ACM/netobserv-metrics.yaml 
```

To debug the above config, check logs here:

```bash
oc logs -n open-cluster-management-addon-observability -l component=metrics-collector
```

Deploying dashboards:

```bash
oc apply -f examples/ACM/dashboards
```

Metrics resolution = 5 minutes

Designing dashboards: https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.8/html/observability/using-grafana-dashboards#setting-up-the-grafana-developer-instance

