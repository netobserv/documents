# What's new in Network Observability 1.6

Network Observability 1.6 was released on June 17, 2024.  Even though this is considered a minor version upgrade from 1.5, it is a significant release that could lower the barrier to adoption into production.

But before we go further, for those of you new to Network Observability, NetObserv, for short, is an optional operator that provides a slew of capabilities to track and provide insight into your network traffic flows.  While it works on any Kubernetes cluster, it works even better in an OpenShift environment, which is what I will focus on in this article.  I will only discuss the new features in this release so if you want the full feature list, read the documentation on [About Network Observability](https://docs.openshift.com/container-platform/4.16/observability/network_observability/json-flows-format-reference.html).


## Graphs and Logs Without Loki and Storage

Let's get right to the crux of the issue.  Prior to 1.4, NetObserv required an external component called Loki as well as storage, such as an S3 bucket, to store logs.  These flow logs allowed NetObserv to provide a rich UI to display graphs, tables, and a topology.  The resources required by Loki can be significant, particularly if you have lots of traffic and are sampling all data, not to mention the storage required.  In 1.4 and 1.5, if you have your own observability platform and only need the flow logs data, you can simply export this data and not install Loki or provide storage.  When you do this, you essentially get no UI besides some minimal flow metrics in **Observe > Dashboards**, because the expectation is that your platform will provide the features and the visuals.

This release changes that premise.  It brings back the graphs in the **Overview** panel and the topology in the **Topology** panel.  This is huge because the core of Network Observability is now fully functional at a fraction of the resources required when Loki is used!  It achieves this by creating Prometheus metrics from the flows and storing them at 5-minute intervals.

So what's the catch?  Without storing the flow logs as JSON data, there will be some impact.  The most notable is that there won't be a traffic flows table, because flows are no longer stored (Figure 1).

![Traffic flows grayed out](images/traffic_flows-grayed_out.png)
_<div style="text-align: center">Figure 1: Traffic flows grayed out</div>_

The other point to understand is that the metrics don't have information at the pod level so for example, in the topology, the **Resource** scope, which shows the pod to pod/service communication, will not exist (Figure 2).

![Topology](images/topology-no_resources.png)
_<div style="text-align: center">Figure 2: Topology - No "Resources"</div>_

A couple of other features, namely packet drop reason and multi-tenancy, are not supported but will be addressed in a follow on release.  If you need any of these capabilities, then go ahead and install Loki and provide storage as usual.

Let's walk through how to configure a Loki-less setup.  Install the Network Observability Operator.  In **Operators > Installed Operators**, click the **Flow Collector** link, and then **Create FlowCollector**.  Click **Loki client settings** to open this up (Figure 3).

![Loki client settings](images/flp-loki_client_settings.png)
_<div style="text-align: center">Figure 3: Loki client settings</div>_

By default, Loki is enabled so set **Enable** to false.  That's it!

There is one other note worth mentioning.  Even if you do install Loki, by default, it will favor using the metrics instead of Loki for querying whenever possible.  By doing this, not only will it be faster, but it will be possible to query data over a period of weeks or months.  This behavior can be changed under **Prometheus**, **Querier** in the **Enable** setting (Figure 4).

![Prometheus settings](images/flp-prometheus.png)
_<div style="text-align: center">Figure 4: Prometheus settings</div>_


## eBPF Agent Enhancements

The eBPF Agent probes the network interfaces and generates flows when it sees network traffic.  There were a number of eBPF Agent enhancements made.  Let's go through them one-by-one.

### Deploy on specific nodes

By default, the eBPF Agent is deployed on each node using a DaemonSet.  If you know for sure that you do not need to run it on all nodes, you can control which nodes to deploy it on.  This is actually a [Kubernetes feature](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) in the scheduler that is now implemented in the eBPF Agent.  There are many ways to do this, and the following uses node affinity to deploy the eBPF Agent only on pods with a specific label.

```
  agent:
    ebpf:
      advanced:
        scheduling:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                - matchExpressions:
                  - key: ebpf-agent
                    operator: In
                    values:
                    - "true"  # make sure this has quotes
```

If you have **oc** installed on your computer, enter `oc edit flowcollector -n netobserv-privileged`.  Look for the `ebpf` section and add the lines above starting at `advanced`.  You can also do this in Web console.  Go to **Operators > Installed Operators**.  Look for the **Network Observability** row, click the **Flow Collector** link and then the **cluster** link.  Because this is an advanced feature, it is not in Form view, so click the **YAML** tab to edit the manifest.

Now this will only deploy on nodes with the `ebpf-agent=true` label.  Set this label by replacing *node-name* with your node name below.

```
oc label nodes node-name ebpf-agent=true
```

### Filter at eBPF level

Network Observability always had great filtering capability in the **Network Traffic** panel.  However, that is done at the UI level, meaning the flows are still generated and stored, and hence resources are being used.  If resources are a major concern, consider this feature ***if*** the filtering fits your requirements.

If you want to generate flows (or not generate flows) for very specific data, you can specify a single filter to do this.  Here's an example to only generate flows for network traffic on TCP port 6443.

```
  agent:
    ebpf:
      flowFilter:
        enable: true
        action: Accept
        cidr: 0.0.0.0/0  # refers to any traffic
        ports: 6443
        protocol: TCP
```

Enter `oc edit flowcollector -n netobserv-privileged`.  Again, look for the `ebpf` section and add the rest of the lines starting at `flowFilter`.  The `cidr` specifies a network address and prefix.  The example refers to any traffic, but for a specific network, use something like 10.0.62.0/24.  The feature is limited to one filter and many of the attributes can only have one value.

### eBPF Agent metrics

You can view statistics for eBPF Agent.  This is in Web console under **Observe > Dashboards**.  Select **NetObserv / Health** in the Dashboard dropdown (Figure 5).  There are graphs for eviction rates, dropped flow rates, and more.

![eBPF Agent statistics](images/ebpf_agent_statistics.png)
_<div style="text-align: center">Figure 5: eBPF Agent statistics</div>_

### Other eBPF changes

Here are a few other minor eBPF changes.

1. Option to alert if it's dropping flows<br>
There is a new option in FlowCollector to control whether an alert is shown if it's dropping flows (Figure 6).  By default, this is enabled.

![Disable alerts](images/ebpf_metrics_configuration.png)
_<div style="text-align: center">Figure 6: eBPF Agent configuration - Disable alerts</div>_

2. Use enhanced TCx hook<br>
Internally, the eBPF Agent uses the Traffic Control (TC) hook to probe the ingress and egress traffic on the interfaces.  In OCP 4.16, which upgrades RHEL to 9.4, it can leverage the enhanced TCx hook for performance gains.

3. Always save DNS flags<br>
If the *DNSTracking* feature is enabled, regardless of the sampling setting, it always saves the DNS id and flags.  Previously, it would discard this data if the flow didn't exist.


## Flow Collector Enhancements

A few enhancements were made in Flow Collector.  They are:

1. Filter on not 'ip'<br>
In **Observe > Network Traffic**, for the IP-related filter fields, such as SourceIP, Destination IP, Source Node IP, and Destination Node IP, you can filter by *not* matching or excluding that IP or range (Figure 7).

![Not 'ip' filter](images/not_ip_filter.png)
_<div style="text-align: center">Figure 7: Not 'ip' filter</div>_

2. De-duplication of flows<br>
    When a flow is a duplicate on another interface, instead of saving multiple copies of that flow data, only one is stored now.  It keeps track of the list of interfaces that refer to the flow data.  This greatly reduces the amount of storage.

    The raw JSON fields have been renamed and pluralized to `Interfaces` and `IfDirections`, since the type changed to a list from a single value.  Note the use of square brackets for the lists below.

    ```
      "IfDirections": [
        0
      ],
      "Interfaces": [
        "br-ex"
      ],
    ```

3. Subnet labels<br>
    You can define a list of names for CIDRs (IP ranges and/or hosts).  When the CIDR matches, the name appears in the flow data as the `SrcSubnetLabel` or `DestSubnetLabel` field.

    YAML Example:

    ```
      processor:
        subnetLabels:
          customLabels:
          - cidrs:
            - 10.129.0.73/32  # provide a name for this host
            name: querier
          openShiftAutoDetect: false
    ```

    If you don't want to define names, you can enable the OpenShift auto-detect mode to identify the items as "Pods", "Services", "Machines" or "n/a" (not applicable).  You configure this in the Processor section of Flow Collector (Figure 8).

![Subnet labels configuration](images/subnet_labels_configuration.png)
    _<div style="text-align: center">Figure 8: Subnet labels configuration</div>_

   Figure 9 shows the subnet label columns in the Traffic flow table when OpenShift auto-detect is enabled.

![Subnet labels columns](images/subnet_labels_columns.png)
    _<div style="text-align: center">Figure 9: Subnet labels columns</div>_


## Custom Metrics

In my [Network Observability 1.5 blog](https://developers.redhat.com/articles/2024/03/20/whats-new-network-observability-15), I covered the development preview of the FlowMetrics API.  While it's possible to take any [flow data labels](https://docs.openshift.com/container-platform/4.16/network_observability/json-flows-format-reference.html) and turn it into a Prometheus metric, that web page was updated to indicate which fields can be safely used as labels to avoid high cardinality.

This feature is now GA, and includes more filtering options (see [reference](https://github.com/netobserv/network-observability-operator/blob/main/docs/FlowMetric.md)) and support for [dashboards in OpenShift](https://github.com/netobserv/network-observability-operator/blob/main/docs/Metrics.md#charts-openshift-only).  That link also has many more examples of using custom metrics.


## Network Observability CLI

This release has yet another significant technical preview feature called Network Observability CLI (NetObserv CLI).  It is a kubectl plug-in that effectively installs Network Observability from the command line but is text-based only.  When you exit the program, it cleans up and removes itself.  In other words, you can now run Network Observability on-demand!

While it reuses much of the NetObserv code, it is separate from the Network Observability Operator.  This means even if you have NetObserv running, you can still run the NetObserv CLI independently.

It is also not just a subset of features of the Network Observability Operator.  There is an option to capture packets and save them in a pcap file to be used by a network analysis tool like Wireshark!  Here is a sample screenshot of NetObserv CLI that is filtering and displaying traffic on port 443 (Figure 10).

![netobserv_cli](images/netobserv_cli.png)
_<div style="text-align: center">Figure 10: Network Observability CLI</div>_

To install this, download the [NetObserv CLI tar file](https://mirror.openshift.com/pub/openshift-v4/clients/netobserv/latest/netobserv-cli.tar.gz) and run the following commands:

```
tar xvf netobserv-cli.tar.gz
chmod +x build/oc-netobserv
sudo mv build/oc-netobserv /usr/local/bin
```

This can also be installed and managed by [Krew](https://krew.sigs.k8s.io/), the kubectl plug-in manager.  If you have Krew, install with:

```
oc krew install netobserv
```

To verify the installation, enter:

```
oc netobserv version
```

To get help, enter:

```
oc netobserv help
```

Figure 10 was run using:

```
oc netobserv flows --enable_filter=true --protocol=tcp --port=443
```

To stop the program, press ctrl-C.  More information about NetObserv CLI will be provided in a future blog.  In the meantime, enjoy!


## Closing

If you are hesitant about deploying Network Observability, fear not.  With Network Observability CLI, you can experiment and have it completely removed when you are done using it.  The second option lets you install Network Observability without Loki, while still providing the majority of the features of this operator.

What are you waiting for?  Give it a try, and let us know what you think at the [discussion board](https://github.com/netobserv/network-observability-operator/discussions).

---

Special thanks to Joel Takvorian, Julien Pinsonneau, and Sara Thomas for providing information for this article.
