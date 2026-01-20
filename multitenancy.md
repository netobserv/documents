# Multi-tenancy

For multi-tenancy, Loki needs either to be installed in LokiStack mode (with the Loki Operator), or to be disabled. Other Loki modes don't allow multi-tenant access.

Refer to [loki_operator.md](./loki_operator.md) for installing Loki operator.

## Non-admin user access

```bash
# For Loki
oc adm policy add-cluster-role-to-user netobserv-loki-reader test
# For Prometheus
oc adm policy add-role-to-user netobserv-metrics-reader test -n <namespace>

# For FlowCollectorSlices (not needed for project admins)
oc adm policy add-role-to-user flowcollectorslices.flows.netobserv.io-v1alpha1-admin test -n <namespace>
```

## Testing

Using the loki-operator 5.7 (or above) + FORWARD mode allows multi-tenancy, meaning that in this mode, user permissions on namespaces are enforced so that users would only see flow logs from/to namespaces that they have access to. You don't need any extra configuration for NetObserv or Loki. Here's a suggestion of steps in order to test it in OpenShift:

- Install Loki Operator + NetObserv as mentioned in [loki_operator.md](./loki_operator.md).
- If you haven't created a project-admin user yet:
  - In ocp console, go to "Users management" > "Users" and click on "Add IDP". For a quick test you can use a "Htpasswd" type
  - E.g. set as content: `test:$2y$10$Z2CXWdNCkp6rvoR5bmbI8OyiTYsUreOMn6sV2UNzpl9c1Eb1vBqO.` which stands for user `test` / `test`.
- Wait a few seconds or minutes that the IDP is working, then login (e.g. in browser incognito mode - you should see the new htpasswd option from the login screen)
- Create a new project named "test" from this session. By doing so, the user is a project-admin on that namespace.
- Deploy some workload in this namespace that will generate some flows (you don't need to do so as the test user - doing so as a cluster admin works as well)
  - E.g. `kubectl apply -f https://raw.githubusercontent.com/jotak/demo-mesh-arena/main/quickstart-naked.yml -n test`
- In the admin perspective, a new "Observe" menu should have appeared, with "Network Traffic" as the only page. Go to Network Traffic.
- You should see an error (403). It's expected: the user needs to have explicit permission to get flows.
  - Apply the role binding: `oc adm policy add-cluster-role-to-user netobserv-loki-reader test`
- Refresh the flow logs: you should see traffic, limited to the allowed namespace.
