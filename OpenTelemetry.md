# OpenTelemetry (otlp)

NetObserv can export flow logs or metrics to an otlp collector.

## Setup with Red Hat OpenTelemetry operator

1. Install "Red Hat build of OpenTelemetry" from operatorhub.
2. Create an `OpenTelemetryCollector` from [otlp.yaml](./examples/otlp/otlp.yaml):
  ```bash
  kubectl apply -f https://raw.githubusercontent.com/netobserv/documents/main/examples/otlp/otlp.yaml
  ```
3. Install netobserv and set up an exporter with:
  ```yaml
    exporters:
    - openTelemetry:
        logs:
          enable: true
        metrics:
          enable: true
          pushTimeInterval: 20s
        targetHost: otlp-collector-headless.netobserv.svc
        targetPort: 4317
      type: OpenTelemetry
  ```

## Checking received data

### Logs

When showing logs from the otlp pod, you should get a summary of the received records, e.g:

```bash
kubectl logs otlp-collector-7cbc5679c9-2slkh

# OUTPUT:
2025-04-08T13:13:19.337Z	info	service@v0.119.0/service.go:186	Setting up own telemetry...
# [...]
2025-04-08T13:13:19.338Z	info	service@v0.119.0/service.go:275	Everything is ready. Begin running and processing data.
2025-04-08T13:18:21.430Z	info	Logs	{"kind": "exporter", "data_type": "logs", "name": "debug", "resource logs": 190, "log records": 190}
2025-04-08T13:18:26.425Z	info	Logs	{"kind": "exporter", "data_type": "logs", "name": "debug", "resource logs": 160, "log records": 160}
2025-04-08T13:18:31.426Z	info	Logs	{"kind": "exporter", "data_type": "logs", "name": "debug", "resource logs": 200, "log records": 200}
2025-04-08T13:18:33.940Z	info	Logs	{"kind": "exporter", "data_type": "logs", "name": "debug", "resource logs": 61, "log records": 61}
```

You can get the full details by configuring `OpenTelemetryCollector` with `spec.config.exporters.debug.verbosity`: "detailed".

## Metrics

Check the re-exporting endpoint:

```bash
kubectl exec -it otlp-collector-7cbc5679c9-2slkh -- curl localhost:8889/metrics

# OUTPUT:
netobserv_workload_ingress_bytes_total{DstSubnetLabel="",SrcSubnetLabel="",destination_k8s_kind="Pod",destination_k8s_namespace_name="openshift-service-ca-operator",destination_k8s_owner_kind="Deployment",destination_k8s_owner_name="service-ca-operator",job="netobserv-otlp",k8s_layer="infra",source_k8s_kind="Pod",source_k8s_namespace_name="openshift-monitoring",source_k8s_owner_kind="StatefulSet",source_k8s_owner_name="prometheus-k8s"} 4210
# [...]
```
