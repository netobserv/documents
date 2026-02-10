<!-- 

Ref: https://github.com/cncf/toc/blob/main/toc_subprojects/project-reviews-subproject/general-technical-questions.md

The General Technical Review questions can be completed by a project team in lieu of a presentation to a Technical Advisory Group (TAG) as well as to satisfy several of the Engineering Principle requirements for applying to CNCF Sandbox as well as applying to move to Incubation and Graduation.

For the purposes of the general technical review and further domain reviews, the questions are designed to prompt design thinking for ready-for-production projects and architecture. The intent is to understand and validate the cloud native software lifecycle of the project and whether it is in line with the CNCF Maturation process and levels. 

Project maintainers are expected to have designed the project for cloud native use cases and workloads, as well as taking a ‘secure by design and secure by default’ approach that enables adopters and consumers of the project the ability to ‘loosen’ the defaults in a manner that suits their environment, requirements and risk tolerance.

These questions are to gather knowledge about the project. Project maintainers are expected to answer to the best of their ability. **_Not every question will be addressable by every project._**

**Suggestion:** A recorded demo or diagram(s) may be easier to convey some of the concepts in the questions below. The project maintainers may provide a link to a recorded demo or add architectural diagrams along with your GTR questionnaire.

-->

# General Technical Review - NetObserv / Sandbox

- **Project:** NetObserv
- **Project Version:** 1.11 and above
- **Website:** https://netobserv.io/
- **Date Updated:** 2026-02-10
- **Template Version:** v1.0
- **Description:** <!-- Short project description --> 

NetObserv is a set of components used to observe network traffic by generating NetFlows from eBPF agents with zero-instrumentation, enriching those flows using a Kubernetes-aware configurable pipeline, exporting them in various ways (logs, metrics, Kafka, IPFIX...), and finally providing a comprehensive visualization tool for making sense of that data, a network health dashboard, and a CLI. Those components are mainly designed to be deployed in Kubernetes via an integrated Operator, although they can also be used as standalones.

The enriched NetFlows consist of basic 5-tuples information (IPs, ports…), metrics (bytes, packets, drops, latency…), kube metadata (pods, namespaces, services, owners), cloud data (zones), CNI data (network policy events), DNS (codes, qname) and more.

The Network Health dashboard comes with its own set of health information derived from NetObserv data, and can also integrate data from other / third-party components, or customized data from users. An API is also provided for users to fully customize the generated metrics for their own use (e.g. for customized alerts).

The CLI is a separate tool independent from the Operator, that provides similar functionality, but tailored for on-demand monitoring (as opposed to 24/7), and adds a packet capture (pcap) functionality.

NetObserv is largely CNI-agnostic, although some specific features can relate to a particular CNI (e.g: getting network events from ovn-kubernetes).


## Day 0 - Planning Phase

### Scope

  * Describe the roadmap process, how scope is determined for mid to long term features, as well as how the roadmap maps back to current contributions and maintainer ladder?

NetObserv is the upstream of Red Hat [Network Observability](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/network_observability/index) for OpenShift. As such, a large part of the roadmap comes from the requirements on that downstream product, while it benefits equally to the upstream (there are no downstream-only features).

TBC...

  * Describe the target persona or user(s) for the project?

The project targets both cluster administrators and project teams. Cluster administrators have a cluster-wide view over all the network traffic, full topology, access to metrics and alerts. They can run packet-capture, they configure the cluster-scoped flow collection process.

Through multi-tenancy, project teams have access to a subset of the traffic and the related topology. They have limited configuration options, such as per-namespace sampling or traffic flagging.

  * Explain the primary use case for the project. What additional use cases are supported by the project?

Observing the network runtime traffic with different levels of granularity and aggregations, receiving network health info such as saturation, degraded latency, DNS issues, etc. Troubleshooting network issues, narrowing down to specific pods or services, deep-diving in netflow data or pcap. Being alerted.

With OVN-Kubernetes CNI, network policy troubleshooting, and network isolation (UDN) visualization.

  * Explain which use cases have been identified as unsupported by the project.  

Currently, network policy troubleshooting with other CNI than OVN-Kubernetes are not supported.

L7 observability not planned to this date (no insight into http specific data such as error codes or URLs; NetObserv operates at a lower level).

  * Describe the intended types of organizations who would benefit from adopting this project. (i.e. financial services, any software manufacturer, organizations providing platform engineering services)?  

All types of organizations may benefit from network observability.

  * Please describe any completed end user research and link to any reports.

### Usability

* How should the target personas interact with your project?

Configuration is done entirely through the CRD APIs, managed by an k8s operator. It is gitops-friendly. A web console is provided for the network traffic and network health visualization. Metrics and alerts are provided for Prometheus, meaning that the users can leverage their existing tooling if they already have it. A command-line interface tool is also provided, independently from the operator, allowing users to troubleshoot network from the command line.

* Describe the user experience (UX) and user interface (UI) of the project.

The provided web console offers two views: Network Traffic (flows visualization) and Network Health (health rules and alerts visualization). The Network Traffic view itself consists in three subviews:
  - an overview of the traffic, showing various charts
  - a table displaying a flat list of network flows
  - a topology graph

In all these views, traffic can be filtered by any data (e.g. by pod, namespace, IP, port, drop cause, dns error, etc.)

In traffic overview and topology, traffic can be aggregated at different levels (e.g. per namespace, per cloud availability zone, etc.)

A special attention is paid to the UX with many small details, to quickly filter on a displayed element, step into an aggregated topology element, etc.

* Describe how this project integrates with other projects in a production environment.

NetObserv can generate many metrics, ingested by Prometheus, and alerting rules for AlertManager. Users who already use them can leverage their existing setup.

For comprehensive observability, NetObserv can also send the network flows to Grafana Loki, and/or export them to other systems by different means: using the IPFIX standard, or the OpenTelemetry protocol (as logs or as metrics), or to a Kafka broker. Those exporting options allow to integrate with many different systems (Splunk, ElasticSearch, etc.)

In OpenShift, the web console comes as a plugin for the OpenShift Console, ensuring a smooth integration.

In the future, we may investigate other UI integration, such as with Headlamp.

### Design

  * Explain the design principles and best practices the project is following.   

The project design principles and best practices are globally common to many Red Hat products. The development philosophy is "upstream first", meaning that there is no hidden code/feature that only downstream users would get. In fact, there is even no specific repository for downstream.

All contributions happen on our GitHub repositories, which are public, go through code reviewing, automated testing, and generally manual testing. A special attention is given to performance: regressions are tracked with several tools, based on kube-burner.

We expect a reasonably high code quality standard, without being too picky on style matters. The goal is not to discourage new contributors.

All architectural decisions are made with care, and must be well balanced according to their drawbacks. When that happens, we expect to discuss a list of pros and cons thoughtfully. One aspect that is often overlooked at first is the impact on the maintenance and support workloads.

  * Outline or link to the project’s architecture requirements? Describe how they differ for Proof of Concept, Development, Test and Production environments, as applicable.

??

  * Define any specific service dependencies the project relies on in the cluster.  

Both the NetObserv operator and the `flowlogs-pipeline` component interact with the Kube API server to watch resources and, for the operator, to create or update them.

As mentioned before, NetObserv has dependencies on Loki and Prometheus. NetObserv does not install any of them, they must be installed separately (except for Loki when configured in "demo" mode). The provided helm chart includes those dependencies as optional, to simplify the installation, but they remain unmanaged. It is not required to use Loki though, it can be disabled in configuration, in which case NetObserv relies solely on Prometheus metrics, but losing precision in the process (data in Prometheus is more aggregated).

Optionally, Kafka can be used at a pre-ingestion stage for a production-grade, high-availability deployment (e.g, using Strimzi).

Finally, several services require TLS certificates, which are generally provided by cert-manager or OpenShift Service Certificates.

  * Describe how the project implements Identity and Access Management.

On the ingestion side, there is no Identity and Access Management other than with the components service accounts themselves, associated with RBAC permissions.

On the consuming side, NetObserv does not implement by itself Identity and Access Management, however all queries run against Loki or Prometheus forward the Authorization header, delegating this aspect to those backends. In a production-grade environment, Thanos and the Loki Operator can be used to enable multi-tenancy. This is how it is implemented in OpenShift.

  * Describe how the project has addressed sovereignty.

Open-source addresses independence.

NetObserv does not store any data directly, this is delegated to Loki and/or Prometheus and the aforementioned exporting methods. All these options offer a very decent flexibility in terms of storage options, with interoperability, which should not cause any independence blockers.

  * Describe any compliance requirements addressed by the project.

??

Downstream builds are FIPS compliant (those build recipes are open-source as well).

  * Describe the project’s High Availability requirements.

High availability can be implemented by using Kafka deployment model (e.g. with Strimzi), and using an autoscaler for the `flowlogs-pipeline` component. Loki and Prometheus should be configured for high availability as well (this aspect is not managed by NetObserv itself; using Thanos and the Loki Operator can serve this purpose).

  * Describe the project’s resource requirements, including CPU, Network and Memory.

Resource requirements highly depend on the cluster network topology: how many nodes and pods you have, how much traffic, etc. While eBPF ensures a minimal impact on workload performance, the generated network flows can represent a significant amount of data, which impact nodes CPU, memory and bandwitdh. Some [recommendations](https://github.com/netobserv/network-observability-operator/blob/main/config/descriptions/ocp.md#resource-considerations) are provided, but your mileage may and will vary. Some statistics are documented [here](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/network_observability/configuring-network-observability-operators#network-observability-resource-recommendations_network_observability).

Mitigating high resource requirements can be done in several ways, such as by increasing the sampling interval, adding filters, or considering whether or not to use Loki. More information [here](https://github.com/netobserv/network-observability-operator/tree/main?tab=readme-ov-file#configuration).

  * Describe the project’s storage requirements, including its use of ephemeral and/or persistent storage.

Storage is not directly managed by NetObserv, and is to be configured via Prometheus and/or Loki. TTL is important to consider. Loki is often configured with a S3 backend storage, but other options exist, such as ODF. Just like memory, storage requirements highly depend on the cluster network topology, and can be mitigated the same way as mentioned above.

  * Please outline the project’s API Design:

NetObserv defines several APIs:
- The [FlowCollector CRD](https://github.com/netobserv/network-observability-operator/blob/main/docs/FlowCollector.md) contains the main, cluster-wide configuration for NetObserv.
- The [FlowMetric CRD](https://github.com/netobserv/network-observability-operator/blob/main/docs/FlowMetric.md) allows users to entirely customize metrics derived from network flows.
- The [FlowCollectorSlice CRD](https://github.com/netobserv/network-observability-operator/blob/main/docs/FlowCollectorSlice.md) allows cluster admins to delegate some of the configuration to project teams.
- The [flows format reference](https://github.com/netobserv/network-observability-operator/blob/main/docs/flows-format.adoc) describes the structure and content of a network flow, which can be consumed in various ways.
- Additionally, [there is some documentation](https://github.com/netobserv/network-observability-operator/blob/main/docs/HealthRules.md#creating-your-own-rules-that-contribute-to-the-health-dashboard) on how users can leverage the Network Health dashboard with customized metrics and alerts, involving some less formal API.

The project CRDs follow standard Kubernetes API conventions as well as the OpenShift ones as best effort. Deviating from them is not impossible but must be argumented.

The project configuration is designed to work well with minimal configuration. This is especially true in OpenShift, thanks to its opinionated nature, but less true in other environments.

The default configuration is designed to work well on small/mid-sized clusters, ie. between roughly 5 and 50 nodes, with a default sampling interval set to 50 in order to preserve resource usage (as opposed to an interval of 1, which would capture all the traffic). On bigger cluster topologies, it is recommended to optimize carefully.

Best effort is done to achieve security by default, but this is sometimes too dependent on the environment. For instance, while a network policy is installed by default in OpenShift, it is not when running in a different environment, as this may break with some CNIs. In that case, enabling the network policy must be done explicitely, or the user can configure their own policy.

Loki must be configured accordingly to its installation, disabled, or enabled in "demo" mode. Prometheus querier URL must be configured. It is recommended to enable the embedded network policy, or to install one. In OpenShift, Prometheus and the network policy are enabled and configured automatically.

    * Describe any new or changed API types and calls \- including to cloud providers \- that will result from this project being enabled and used  
    * Describe compatibility of any new or changed APIs with API servers, including the Kubernetes API server   
    * Describe versioning of any new or changed APIs, including how breaking changes are handled

The project release process is split between upstream and downstream releases. For both of them, content can be tracked from the repositories, which are public.

Upstream releases happen from the `main` branches without a well-defined cadence. They use GitHub workflows to generate images and artifacts, triggered by git tags. Versions are suffixed with `-community`, e.g. `v1.11.0-community`. A helm chart is manually updated after each component is released. The release process is described [here](https://github.com/netobserv/network-observability-operator/blob/main/RELEASE.md).

Downstream releases happen from release branches (e.g. `release-1.11`) and use Konflux / Tekton. They produce an OLM bundle and OLM catalog fragments. They are loosely aligned with OpenShift releases.

Versioning upstream and downstream is aligned on "major.minor", but not necessarily on ".patch". For instance, downstream `v1.2.3` and `v1.2.3-community` should have the same features (in `1.2`) but not necessarily the same fixes/patches (in `.3`).

### Installation

Upstream releases can be installed via Helm, as [documented here](https://github.com/netobserv/network-observability-operator/blob/main/README.md#getting-started). From a fresh/vanilla cluster (e.g. using KIND), it can be done in 5 commands (installing cert-manager, installing NetObserv, configuring a `FlowCollector`).

Testing and validating the installation can be done by port-forwarding the web console URL and checking its content. This is described in the same link above.

### Security

<!-- 
  * Please provide a link to the project’s cloud native [security self assessment](https://tag-security.cncf.io/community/assessments/).  
  * Please review the [Cloud Native Security Tenets](https://github.com/cncf/tag-security/blob/main/community/resources/security-whitepaper/secure-defaults-cloud-native-8.md) from TAG Security.  
    * How are you satisfying the tenets of cloud native security projects?  
    * Describe how each of the cloud native principles apply to your project.  
    * How do you recommend users alter security defaults in order to "loosen" the security of the project? Please link to any documentation the project has written concerning these use cases.  
  * Security Hygiene  
    * Please describe the frameworks, practices and procedures the project uses to maintain the basic health and security of the project.   
    * Describe how the project has evaluated which features will be a security risk to users if they are not maintained by the project?  
  * Cloud Native Threat Modeling  
    * Explain the least minimal privileges required by the project and reasons for additional privileges.  
    * Describe how the project is handling certificate rotation and mitigates any issues with certificates.  
    * Describe how the project is following and implementing [secure software supply chain best practices](https://project.linuxfoundation.org/hubfs/CNCF\_SSCP\_v1.pdf) 
-->
- [Self assessment](./Security%20Self-Assessment.md)
- On TAG Security whitepaper:
1. Make security a design requirement
Security measures have been baked in from GA day-0, and continuously improved over time. For instance, from day-0, TLS / mTLS has been recommended through Kafka; RBAC and multi-tenancy supported via the Loki Operator; eBPF agents, running with elevated privileges, are segregated in a different namespace; fine-grained capabilities are favored whenever possible. A threat modeling as been done internally at Red Hat.
2. Applying secure configuration has the best user experience
Security by default is preferred, although not always possible. Servers use TLS by default. eBPF agents run in non-privileged mode by default.
Network policy is unfortunately not always installed by default, as it may blocks communications unexpectedly with some CNIs, but it does in OpenShift.
3. Selecting insecure configuration is a conscious decision
Features that require the eBPF agent privileged mode will not automatically enable it: it remains a conscious decision.
4. Transition from insecure to secure state is possible
All the configuration is managed through the Operator with a typical reconciliation, which ensures transitions work seemlessly, in one way or another.
5. Secure defaults are inherited
NetObserv does not override any known secure defaults.
6. Exception lists have first class support
N/A
7. Secure defaults protect against pervasive vulnerability exploits.
Containers run as non-root; Release pipeline includes vulnerability scans.
8. Security limitations of a system are explainable
While security limitations are not hidden, they may not be very visible. This is something to add to the roadmap.

TBC


## Day 1 \- Installation and Deployment Phase

### Project Installation and Configuration

<!-- 
  * Describe what project installation and configuration look like.
-->

### Project Enablement and Rollback

<!-- 
  * How can this project be enabled or disabled in a live cluster? Please describe any downtime required of the control plane or nodes.  
  * Describe how enabling the project changes any default behavior of the cluster or running workloads.  
  * Describe how the project tests enablement and disablement.  
  * How does the project clean up any resources created, including CRDs?
-->

### Rollout, Upgrade and Rollback Planning

<!-- 
  * How does the project intend to provide and maintain compatibility with infrastructure and orchestration management tools like Kubernetes and with what frequency?  
  * Describe how the project handles rollback procedures.  
  * How can a rollout or rollback fail? Describe any impact to already running workloads.  
  * Describe any specific metrics that should inform a rollback.  
  * Explain how upgrades and rollbacks were tested and how the upgrade-\>downgrade-\>upgrade path was tested.  
  * Explain how the project informs users of deprecations and removals of features and APIs.  
  * Explain how the project permits utilization of alpha and beta capabilities as part of a rollout.
-->

## Day 2 \- Day-to-Day Operations Phase

### Scalability/Reliability

<!-- 
  * Describe how the project increases the size or count of existing API objects.
  * Describe how the project defines Service Level Objectives (SLOs) and Service Level Indicators (SLIs).  
  * Describe any operations that will increase in time covered by existing SLIs/SLOs.  
  * Describe the increase in resource usage in any components as a result of enabling this project, to include CPU, Memory, Storage, Throughput.  
  * Describe which conditions enabling / using this project would result in resource exhaustion of some node resources (PIDs, sockets, inodes, etc.)  
  * Describe the load testing that has been performed on the project and the results.  
  * Describe the recommended limits of users, requests, system resources, etc. and how they were obtained.  
  * Describe which resilience pattern the project uses and how, including the circuit breaker pattern.
-->

Load tests are performed very regularly on different cluster sizes (25 and 250 nodes) to track any performance regression, using prow and kube-burner-ocp. Not all configurations can be tested this way, so the focus is set on very high range of production-grade installations, with Kafka, the Loki Operator, all features enabled, and maximum sampling (capturing all the traffic).

[This page](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/network_observability/configuring-network-observability-operators) shows a short summary of these tests, alongside with resource limits recommendations. More information can be obtained from prow runs, publicly available ([here's an example](https://gcsweb-ci.apps.ci.l2s4.p1.openshiftapps.com/gcs/test-platform-results/logs/periodic-ci-openshift-eng-ocp-qe-perfscale-ci-netobserv-perf-tests-netobserv-aws-4.21-nightly-x86-node-density-heavy-25nodes/2020627868538638336/artifacts/node-density-heavy-25nodes/openshift-qe-orion/artifacts/data-netobserv-perf-node-density-heavy-AWS-25w.csv)).


### Observability Requirements

<!-- 
  * Describe the signals the project is using or producing, including logs, metrics, profiles and traces. Please include supported formats, recommended configurations and data storage.  
  * Describe how the project captures audit logging.  
  * Describe any dashboards the project uses or implements as well as any dashboard requirements.  
  * Describe how the project surfaces project resource requirements for adopters to monitor cloud and infrastructure costs, e.g. FinOps  
  * Which parameters is the project covering to ensure the health of the application/service and its workloads?  
  * How can an operator determine if the project is in use by workloads?  
  * How can someone using this project know that it is working for their instance?  
  * Describe the SLOs (Service Level Objectives) for this project.
  * What are the SLIs (Service Level Indicators) an operator can use to determine the health of the service?
-->

NetObserv own observability relies heavily on Prometheus metrics, and to a lesser extent, unstructured logs and profiling. There is no plan at this time to bake tracing or structured logs directly in the code.

From the 4 components part of the operator (eBPF agent, flowlogs-pipeline, the web console and the operator itself), the eBPF agent and flowlogs-pipeline are the two most critical to observe. They both provide metrics such as:
- Error counters, labeled by code and component.
- Gauges tracking persistent data structure sizes.
- Messages / events counters.
- Some histograms tracking operation latency.

In OpenShift, a Health dashboard is provided to track the most meaningful metrics, alongside with more general ones (CPU, memory, file descriptors, goroutines...). For non-OpenShift, a similar dashboard could be created.

Two Prometheus alerting rules are created, to detect the absence of flows: one for flows received by flowlogs-pipeline, the other for flows written to Loki. Those alerts fire when something prevents NetObserv from running normally.

In addition to the metrics, potential configuration issues, or deployment issues, are reported as FlowCollector Conditions by the operator.

Profiling (pprof) can be enabled by configuring ports in FlowCollector. It triggers a restart of the profiled workloads.

### Dependencies

<!-- 
  * Describe the specific running services the project depends on in the cluster.  
  * Describe the project’s dependency lifecycle policy.  
  * How does the project incorporate and consider source composition analysis as part of its development and security hygiene? Describe how this source composition analysis (SCA) is tracked.
  * Describe how the project implements changes based on source composition analysis (SCA) and the timescale.
-->

### Troubleshooting

<!-- 
  * How does this project recover if a key component or feature becomes unavailable? e.g Kubernetes API server, etcd, database, leader node, etc.  
  * Describe the known failure modes.
-->

### Compliance

<!-- 
  * What steps does the project take to ensure that all third-party code and components have correct and complete attribution and license notices?
  * Describe how the project ensures alignment with CNCF [recommendations](https://github.com/cncf/foundation/blob/main/policies-guidance/recommendations-for-attribution.md) for attribution notices.
-->
<!-- Note that each question describes a use case covered by the referenced policy document.-->
<!-- 
    * How are notices managed for third-party code incorporated directly into the project's source files?
    * How are notices retained for unmodified third-party components included within the project's repository?
    * How are notices for all dependencies obtained at build time included in the project's distributed build artifacts (e.g. compiled binaries, container images)?
-->

### Security

<!-- 
  * Security Hygiene  
    * How is the project executing access control?  
  * Cloud Native Threat Modeling  
    * How does the project ensure its security reporting and response team is representative of its community diversity (organizational and individual)?  
    * How does the project invite and rotate security reporting team members?
-->
