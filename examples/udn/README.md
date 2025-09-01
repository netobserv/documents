## UDN testing

This examples creates 2 namespaces for cluster UDN, each with a pod, and a third namespace for namespaced UDN, with two pods.

Cluster UDN uses `10.100.0.0/16`, whereas namespaced UDN uses `10.150.0.0/16`.

In NetObserv, you must enable the `UDNMapping` agent feature.

### Create namespaces and pods

```bash
oc apply -f https://raw.githubusercontent.com/netobserv/documents/main/examples/udn/namespaces.yaml
oc apply -f https://raw.githubusercontent.com/netobserv/documents/main/examples/udn/pods.yaml
```

### Create UDNs

```bash
oc apply -f https://raw.githubusercontent.com/netobserv/documents/main/examples/udn/cudn.yaml
oc apply -f https://raw.githubusercontent.com/netobserv/documents/main/examples/udn/udn.yaml
```

### Get pods UDN IP

```bash
IP_A=`oc exec -n test-cudn-1 hello-pod-a -- ip a | grep "10.100" | sed -r "s#.*(10\.100\.[0-9]+\.[0-9]+)/.*#\\1#"` && echo "IP_A=$IP_A"
IP_B=`oc exec -n test-cudn-2 hello-pod-b -- ip a | grep "10.100" | sed -r "s#.*(10\.100\.[0-9]+\.[0-9]+)/.*#\\1#"` && echo "IP_B=$IP_B"
IP_C=`oc exec -n test-udn hello-pod-c -- ip a | grep "10.150" | sed -r "s#.*(10\.150\.[0-9]+\.[0-9]+)/.*#\\1#"` && echo "IP_C=$IP_C"
IP_D=`oc exec -n test-udn hello-pod-d -- ip a | grep "10.150" | sed -r "s#.*(10\.150\.[0-9]+\.[0-9]+)/.*#\\1#"` && echo "IP_D=$IP_D"
```

### Test allowed connectivity

```bash
oc exec -n test-cudn-1 hello-pod-a -- curl -s $IP_B:8080 --connect-timeout 5
oc exec -n test-cudn-2 hello-pod-b -- curl -s $IP_A:8080 --connect-timeout 5
oc exec -n test-udn hello-pod-c -- curl -s $IP_D:8080 --connect-timeout 5
oc exec -n test-udn hello-pod-d -- curl -s $IP_C:8080 --connect-timeout 5
```

Each command should show a `Hello OpenShift!` message.

### Test denied connectivity

```bash
oc exec -n test-cudn-1 hello-pod-a -- curl -s $IP_C:8080 --connect-timeout 5
oc exec -n test-udn hello-pod-c -- curl -s $IP_A:8080 --connect-timeout 5
```

Each command should time out.
