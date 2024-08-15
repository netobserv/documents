# Network Observability without Loki

By: Mehul Modi, Steven Lee

Recently, the Network Observability Operator released version  1.6, which added a major enhancement to provide network insights for your OpenShift cluster without Loki. This enhancement was also featured in [What's new in Network Observability 1.6](../whats_new_1.6) blog, providing a quick overview of the feature. In this blog, lets look at some of the advantages and trade-offs users would have when deploying the Network Observability Operator with Loki disabled. As more metrics are enabled by default with this feature, we'll also demonstrate a use-case on how those metrics can benefit users for real world scenarios.

# Configure Network Observability without Loki
Loki as datasource is currently enabled by default. To configure the Network Observability Operator without Loki, set  the `FlowCollector` resource specification, `.spec.loki.enable`, to `false`

```yaml
loki:
  enable: false
```
When Loki is disabled, metrics continue to get scraped by the OpenShift cluster Prometheus without any additional configuration. The Network Traffic console uses Prometheus as a source for fetching the data.

## Performance and Resource utilization gains

### Query performance:
Prometheus queries are blazing fast compared to Loki queries, but don't take my word for it, let's look at the data from the query performance tests: 

Test bench environment:

* **Test**: We conducted 50 identical queries for 3 separate time ranges to render a topology view for both Loki and Prometheus. Such a query requests all K8s Owners for the workload running in an OpenShift Cluster that had  network flows associated to them. Since we did not have any applications running, only Infrastructure workloads generated network traffic. In Network Observability such an unfiltered view renders topology rendered as follows: 

    ![unfiltered topology view](images/owner_screenshot.png)

* **Test bed**: 9 worker and 3 master nodes, AWS m5.2xlarge machines
* **LokiStack size**: 1x.small

Results:

  The following table shows the 90th percentile query times for each table:

  | Time Range | Loki      | Prometheus
  | :--------: | :-------: | :----------:
  | Last 5m    | 984 ms    | 99 ms
  | Last 1h    | 2410 ms   | 236 ms
  | Last 6h    | > 10 s    | 474 ms

As the time range to fetch network flows gets wider, Loki queries tend to get slower or time out, while Prometheus queries are able to render the data within a fraction of a second.

### Resource utilization:
In our tests conducted on 3 different test beds with varied workloads and network throughput, when Network Observability is configured without Loki, total savings of memory usage are in the 45-65% range and CPU utilization is lower by 10-20%<sup>*</sup>. Not to mention you do not need to provision and plan for additional object storage in public clouds for Loki, overall reducing the cost and improving operational efficiency significantly.

In our perf tests, [kube-burner](https://github.com/kube-burner/kube-burner) workloads were used to generate several objects and create heavy network traffic. We used a sampling rate of 1 for all of the following tests:

1. Test bed 1: node-density-heavy workload ran against 25 nodes cluster.
2. Test bed 2: ingress-perf workload ran against 65 nodes cluster.
3. Test bed 3: cluster-density-v2 workload ran against 120 nodes cluster

The following graphs show total vCPU, memory and storage usage for a recommended Network Observability stack  - flowlogs-pipeline, eBPF-agent, Kafka, Prometheus and optionally Loki for production clusters.

![Compare total vCPUs utilized with and without Loki](<blogs/lokiless_netobserv/images/vCPUs consumed by NetObserv stack.png/Total vCPUs consumed.png>)
![Compare total RSS utilized with and without Loki](<blogs/lokiless_netobserv/images/Memory consumed by NetObserv stack.png>)

Let's look at the amount of estimated storage you'd need for all the network flows and Prometheus metrics that Network Observability has to store. For context, even when Loki is installed Network Observability publishes default set of Prometheus metrics for monitoring dashboards, and it adds additional metrics when Loki is disabled to visualize network flows. The graphs below shows the estimated amount of storage required to store 15 days of Network flows (when configured with Loki), Prometheus metrics and Kafka as intermediary data streaming layer between eBPF-agent and flowlogs-pipeline. 

The network flows rate for each test bed was 10K, 13K, 30K flows/second respectively. The storage for Loki includes AWS S3 bucket utilization and its PVC usage. For Kafka PVC storage value, it assumes 1 day of retention or 100 GB whichever is attained first.

![Compare total Storage utilized with and without Loki](<blogs/lokiless_netobserv/images/15 days Storage consumption.png>)

As seen across the test beds, we find a storage savings of 90% when Network Observability is configured without Loki.

<sup>*</sup> actual resource utilization may depend on various factors such as network traffic, FlowCollector sampling size, and the number of workloads and nodes in an OpenShift Container Platform cluster

## Trade-offs:
We saw having Prometheus as datasource provides impressive performance gains and sub-second query times, however it introduces the following constraints:

1. Without storage of network flows data, the Network Observability OpenShift web console no longer provides the Traffic flows table.

![Disabled table view](images/disabled_table_view.png)

2. Per-pod level of resource granularity is not available since it causes Prometheus metrics to have high cardinality.

![Topology scope changes](images/topology_scope.png)
   
   Should you need per-flow or per-pod level of granularity for diagnostic and troubleshooting, other than enabling Loki you have multiple other options available:

   a. Collect flowlogs into your preferred data analytics tool using `.spec.exporters` config in Flowcollector, currently Kafka and IPFIX are supported exporters.

   b. In this release, Network Observability also introduced the `FlowMetrics` API, which lets you create custom metrics that are not available out of the box. The `FlowMetrics` API creates on-demand Prometheus metrics based on enriched flowlogs fields, which can be used as labels for custom Prometheus metrics. _Note: Use this option with caution, as introducing metrics that may have labels with high cardinality increases the cluster's Prometheus resource usage and might impact overall cluster monitoring_.

3. Restricted multi-tenancy - Prometheus in OpenShift cluster currently doesn't support multi-tenancy in a way that Loki does. Non-admin users can be added to `cluster-monitoring-view` where the user can have access to view all available Prometheus metrics.

   For example, the following command can be used to enable Prometheus metrics, visualizing for the`testuser-0` user.

   `oc adm policy add-cluster-role-to-user cluster-monitoring-view  testuser-0`

## Network Observability metrics use case:
Let's look at a scenario about how users can benefit from metrics published by the Network Observability Operator. For instance, if you suspect anomaly with DNS lookups in your cluster and want to investigate workloads that may be facing DNS latencies. With Network Observability's `DNSTracking` feature and enriched Prometheus metrics you can quickly set up an alert to trigger on high DNS latencies.

For example, the following alert is triggered for any workloads that experience a DNS latency > 100ms: 
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

To demonstrate this use-case, I configured  the CoreDNS [erratic plugin](https://coredns.io/plugins/erratic/) in `openshift-dns` namespace to add latencies for `example.org` domain using the following configuration:

```
example.org {
        erratic {
            delay 2 100ms
        }
}
```

Configuring for DNS latencies adds 100ms delay to every 2nd DNS request coming in for `example.org`. A test pod performing DNS lookups for `example.org` every 1 second was created, eventually triggering earlier configured `DNSLatencyAlert` in my OCP cluster.

![DNSLatency alert triggered for threshold > 100ms](images/dns_latency_alert_firing.png)

Similarly, additional alerts on different DNS response codes could be set up, for example an alert for DNS lookup failures such as DNS queries receiving NXDOMAIN or SERVFAIL responses can also be set up as flowlogs and metrics are already enriched with DNS response codes.

In addition to metrics for the `DNSTracking` feature, Network Observability provides metrics for other features, such as Round-Trip-Time and Packet Drops.

## Conclusion and next steps:

Network Observability operator provides the visibility you need to proactively detect issues within OpenShift cluster networking. Now with an option to disable loki, Network Observability operator provides light weight solution to visualize, diagnose and troubleshoot networking issues faster at a lower cost. Network Observability's Prometheus metrics can be leveraged to set up user defined alerts in your OCP cluster.

Whether you have already deployed or considering to deploy Network Observability, we would love to engage with you and hear your thoughts [here](https://github.com/netobserv/network-observability-operator/discussions).

Special thanks to Joel Takvorian, Julien Pinsonneau, and Sara Thomas for providing information for this article.
