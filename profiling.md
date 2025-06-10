## Profiling NetObserv components

All go components use pprof for profiling.

### FLP

In the FlowCollector config, turn on profiling:

```yaml
spec:
  processor:
    advanced:
      profilePort: 6060
```

After a pod restarted, port-forward its profiling port to localhost:

```bash
kubectl port-forward pods/flowlogs-pipeline-27wl8 6060:6060 -n netobserv
```

You can verify that the dashboard is present on http://localhost:6060/debug/pprof/.

Start profiling, e.g. for CPU:

```bash
curl "http://localhost:6060/debug/pprof/profile?seconds=10" > profile10s_1
```

Use the web UI to analyse the data:

```bash
go tool pprof -http=:8080 profile10s_1
```
