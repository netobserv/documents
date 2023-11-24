## Setup ACM with NetObserv metrics

cf also [blog post](./blogs/acm/leverage-metrics-in-acm.md).

This is more a quick guide for the development teams.

Quick guide:

1. Create 2 clusters (or more)
2. Choose one for being the main one / hub: install ACM operator on it; Create a default MultiClusterHub
3. In console top bar, select "all cluster" then start procedure to import an existing cluster. You may define labels "netobserv=true" during import.

You have two options, either you use ACM policies to automate the install, or you install manually netobserv or each cluster.

### Option 1: with ACM policies

Note that this doesn't cover Loki installation, so in this mode Loki & Console plugin will be disabled. Of course it is possible to also automate Loki installation, by creating new policy objects. Feel free to contribute!

```bash
oc apply -f ./examples/ACM/acm-policy-netobserv-1.4.yaml
oc apply -f ./examples/ACM/acm-policy-flowcollector-v1beta1-noloki.yaml
oc apply -f ./examples/ACM/acm-bindings.yaml
```

Then on each cluster you want to include, add the label "netobserv=true" if you haven't already done so. It will enable the policies for it, triggering automated install. You can do it from the console under Infrastructure > Clusters > Edit labels (on each row / kebab menu).

### Option 2: manual install

On each cluster:
1. Install netobserv downstream (user workload prometheus won't work the same way)
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

