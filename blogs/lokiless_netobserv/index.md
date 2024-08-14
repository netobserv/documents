# Network Observability without Loki

By: Mehul Modi, Steven Lee

Recently, Network Observability operator 1.6 released a major enhancement to provide network insights for your OpenShift cluster without Loki. This enhancement was also featured in [What's new in Network Observability 1.6](../whats_new_1.6) blog providing quick overview of the feature. In this blog, lets look at some of the advantages and trade-offs users would have when deploying network observability with Loki disabled. As more metrics are enabled by default with this feature, we'll also demonstrate a use-case on how those metrics can benefit users for real world scenarios.

# Configure Network Observability without Loki
Loki as datasource is currently enabled by default. To configure Network Observability operator without Loki, when configuring Flowcollector resource simply set `.spec.loki.enable` to `false`

```yaml
loki:
  enable: false
```
When configured as above, Network Observability's Prometheus metrics will continue to get scraped by OpenShift's cluster Prometheus without any additonal configuration and Network Traffic console will use Prometheus as a source for fetching the data.

## Performance and Resource utilization gains

### Query performance:
Prometheus queries are blazing fast compared to Loki queries, but don't take my word for it, let's look at the data from the query performance tests: 

Test bench environment:

* Test: We did identical 50 queries for 3 separate time ranges to render topology view for both Loki and Prometheus. Such query requests all K8s Owners for the workload running in an OpenShift Cluster that had  network flows associated to them. Since we didn't have any applications running, it was all Infrastructure workloads generating network traffic. In Network Observability such unfiltered view will have topology rendered as below: 

    ![unfiltered topology view](images/owner_screenshot.png)

* Test bed: 9 worker and 3 master nodes, AWS m5.2xlarge machines
* LokiStack size: 1x.small

Results:

  Below table shows 90th Percentile query times for each table:

  | Time Range | Loki      | Prometheus
  | :--------: | :-------: | :----------:
  | Last 5m    | 984 ms    | 99 ms
  | Last 1h    | 2410 ms   | 236 ms
  | Last 6h    | > 10 s    | 474 ms

As time range to fetch network flows gets wider, Loki queries tends to get slower or timing out, while Prometheus queries is able render the data within fraction of a second.

### Resource utilization:
In our tests conducted on 3 different test beds with varied workloads and network throughput, when Network Observability is configured without Loki, total savings of Memory usage could be in range 45-65% and CPU utilzation could be lower by 10-20%<sup>*</sup>. Not to mention you will not need to provision and plan for additional object storage in public clouds for Loki, overall reducing the cost and improving operational efficiency significantly.

In our perf tests, [kube-burner](https://github.com/kube-burner/kube-burner) workloads were used to generate several objects and create heavy network traffic. We used sampling rate of 1 for all below tests. To further describe each test bed:

1. Test bed 1: node-density-heavy workload ran against 25 nodes cluster.
2. Test bed 2: ingress-perf workload ran against 65 nodes cluster.
3. Test bed 3: cluster-density-v2 workload ran against 120 nodes cluster

Below graphs shows total vCPU, memory and storage usage for a recommended Network Observability stack  - flowlogs-pipeline, eBPF-agent, Kafka, Prometheus and optionally Loki for production clusters.

![Compare total vCPUs utilized with and without Loki](<blogs/lokiless_netobserv/images/vCPUs consumed by NetObserv stack.png/Total vCPUs consumed.png>)
![Compare total RSS utilized with and without Loki](<blogs/lokiless_netobserv/images/Memory consumed by NetObserv stack.png>)

Let's look at the amount of estimated storage you'd need for all the network flows and Prometheus metrics that Network Observability has to store. For context, even when Loki is installed Network Observability publishes default set of Prometheus metrics for monitoring dashboards, and it adds additional metrics when Loki is disabled to visualize network flows. The graphs below shows the estimated amount of storage required to store 15 days of Network flows (when configured with Loki), Prometheus metrics and Kafka as intermediary data streaming layer between eBPF-agent and flowlogs-pipeline. 

The network flows rate for each test bed was 10K, 13K, 30K flows/second respectively. The storage for Loki includes AWS S3 bucket utilization and its PVC usage. For Kafka PVC storage value, it assumes 1 day of retention or 100 GB whichever is attained first.

![Compare total Storage utilized with and without Loki](<blogs/lokiless_netobserv/images/15 days Storage consumption.png>)

As seen across test beds above, we find storage savings of 90% when Network Observability is configured without Loki.

<sup>*</sup> actual resource utilization may depend on various factors such as network traffic, flowcollector sampling size, number of workloads and nodes in an OCP cluster

## Trade-offs:
We saw having Prometheus as datasource provides impressive performance gains and sub-second query times, however it introduces below constraints:

1. Without storage of network flows it no longer provides Traffic flows table.

![Disabled table view](images/disabled_table_view.png)

2. Per-pod level of resource granularity is not available since it causes Prometheus metrics to have high cardinality.

![Topology scope changes](images/topology_scope.png)
   
   Should you need per-flow or per-pod level of granularity for diagnostic and troubleshooting needs, other than enabling Loki you have multiple other options available:

   a. Collect flowlogs into your preferred data analytics tool using `.spec.exporters` config in Flowcollector, currently Kafka and IPFIX are supported exporters.

   b. In this release, Network Observability also introduced `FlowMetrics` API which lets you create custom metrics which may not be available out of the box. `FlowMetrics` API creates on-demand Prometheus metrics based on enriched flowlogs fields which can be used as labels for custom Prometheus metrics. _Note: Be careful with this option though, introducing metrics that may have labels with high cardinality increases cluster's Promethes resource usage and may impact overall cluster monitoring_.

3. Restricted multi-tenancy - Prometheus in OpenShift cluster currently doesn't support multi-tenancy in a way that Loki does, non-admin users can be added to `cluster-monitoring-view` where user will have access to view all available Prometheus metrics.

   For example, below command can be used to enable Prometheus metrics visualizing for `testuser-0` user.

   `oc adm policy add-cluster-role-to-user cluster-monitoring-view  testuser-0`

## Network Observability metrics use case:
Let's look at a scenario how users can benefit from metrics published by Network Observability Operator. For instance, if you suspect anomaly with DNS lookups in your cluster and want to investigate workloads that may be facing DNS latencies. With Network Observability's `DNSTracking` feature and enriched Prometheus metrics you can quickly set up an alert to trigger on high DNS latencies.

For example, below alert will trigger for any workloads that experiences DNS latency > 100ms: 
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: dns-latency-alert
  namespace: netobserv
spec:
  groups:
  - name: DNSLatencyAlert
    rules:
    - alert: DNSLatencyAlert
      annotations:
        message: |-
          {{ $labels.DstK8S_OwnerName }} in {{ $labels.DstK8S_Namespace }} is experiencing high DNS Latencies.
        summary: "Trigger for any workloads experiencing > than 100ms DNS Latency."
      expr: histogram_quantile(0.9, sum(rate(netobserv_workload_dns_latency_seconds_bucket{DstK8S_Namespace!=""}[2m])) by (le,DstK8S_Namespace,DstK8S_OwnerName))*1000 > 100
      for: 10s
      labels:
        severity: warning
```

To demonstrate this use-case, I configured CoreDNS's [erratic plugin](https://coredns.io/plugins/erratic/) in openshift-dns to add latencies for `example.org` domain using below config:

```
example.org {
        erratic {
            delay 2 100ms
        }
}
```

Above config add 100ms delay to every 2nd DNS request coming in for example.org. A test pod performing DNS lookups for `example.org` every 1 second was created, eventually triggering earlier configured `DNSLatencyAlert` in my OCP cluster.

![DNSLatency alert triggered for threshold > 100ms](images/dns_latency_alert_firing.png)

Similarly, additional alerts on different DNS response codes could be set up, for example an alert for DNS lookup failures such as DNS queries receiving NXDOMAIN or SERVFAIL responses can also be set up as flowlogs and metrics are already enriched with DNS response codes.

In addition to metrics for `DNSTracking` feature, Network Observability provides metrics for other features such as Round-Trip-Times and Packet Drops as well.

## Conclusion and next steps:

Network Observability operator provides the visibility you need to proactively detect issues within OpenShift cluster networking. Now with an option to disable loki, Network Observability operator provides light weight solution to visualize, diagnose and troubleshoot networking issues faster at a lower cost. Network Observability's Prometheus metrics can be leveraged to set up user defined alerts in your OCP cluster.

Whether you have already deployed or considering to deploy it, we'd love to engage with you and hear your thoughts [here](https://github.com/netobserv/network-observability-operator/discussions).

Special thanks to Joel Takvorian, Julien Pinsonneau, and Sara Thomas for providing information for this article.
