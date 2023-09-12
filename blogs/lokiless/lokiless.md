# Deploying Network Observability without Loki

## A brief history

When we started the NetObserv project, one of the first architectural question was, as you could expect, which storage solution to adopt. It has to be robust for write-intensive application, with indexing capabilities on large data sets, scalable, while still allowing to run complex queries. It must be able to store structured logs and to extract time-series from them. Features like full-text indexing or data mutability aren't required. On top of that, the license must be compatible with our needs. We ended up with a shortlist that included Grafana Loki, OpenDistro, Influx and a few others. This was two years ago.

We also talked with other OpenShift teams having similar requirements, such as the Logging and the Distributed Tracing teams, and got some feedback to eventually rule out candidates with supposedly higher operational costs. And since the Logging team had already planned to invest in the Loki Operator, that was a nice opportunity to mutualize some efforts. Ok, let's be honest: that was a huge time saver especially for us, thanks so much folks!

## Why changing now?

To be clear, **we aren't actually moving away from Loki**. Loki remains the one and only storage solution that we support at the moment, and our Console plugin is entirely based on queries to Loki, in its _logql_ format. However, we have seen some people using NetObserv in a way that we didn't expect: deploying it without Loki, and configuring flows exporters for instance with Kafka or IPFIX. Why? It turned out they were more interested in the kube-enriched raw flow data than in the visualizations that NetObserv provides, and they didn't want to deal with a new backend storage setup and maintenance. Which, admittedly, is a quite reasonable argument.

To summarize, here's the deal:
- :moneybag:: you save on operational aspects by not deploying Loki or any new storage.
- :broken_heart:: you loose all the fancy dashboards that we build with so much love.
- :woman_factory_worker:: you need to create your own consumers for doing anything with the exported flows.

## What is changed

There was still a problem: NetObserv was designed with Loki as a requirement. If you don't configure the Loki endpoint, our _flowlogs-pipeline_ component still tries to send flows to a default URL (and fail), and our Console plugin still tries to query Loki (and fail). While the latter isn't too annoying for someone who anyway doesn't want to use the Console plugin, the former could be the cause of performance degradation.

So this is what we did: **we simply added an _enable_ knob for Loki**. With Loki turned off, _flowlogs-pipeline_ obviously doesn't try to send anything to it. And since the Console plugin becomes useless without Loki, it isn't deployed anymore in that case.

_TODO: architecture overview diagram with/without loki_

As this diagram shows, what remains of the flows pipeline downstream is:

- The ability to generate Prometheus metrics. Those metrics and their related dashboards are still accessible in the OpenShift Console, independently from our plugin.
- The ability to setup one or several exporters downstream the pipeline, such as via Kafka or to any IPFIX collector. This is then up to you to consume this data for any purpose.

## Example and use case

_TODO: Setup a pipeline with Kafka exporter and a custom storage like postgre or whatever is easy to deploy._
_It should cover:_
- _Netobersv install & setup_
- _Kafka setup_
- _Storage setup_
- _Creating a Kafka consumer (as simple as possible)_
- _Running workloads_
- _Querying flows_

_Maybe add some performance stats to show the diff with/without Loki_

## What's next?

_TODO: future enhancements? New storages? (hopefully with standardized queries https://docs.google.com/document/d/1JRQ4hoLtvWl6NqBu_RN8T7tFaFY5jkzdzsB9H-V370A/edit?pli=1 !) storage-less deployment with Kafka AND console, ie console consumer?_
