# Testing secondary networks (easily)

OpenShift doc:

- [Multiple networks](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html-single/multiple_networks/index#understanding-multiple-networks-con_understanding-multiple-networks)

No need for a bare-metal cluster and VMs. Using cloud-based + ovn-k overlay l2 works just fine.

We'll use here an example with mesh-arena.

1. Deploy some pods

```bash
kubectl create namespace mesh-arena ; kubectl apply -f https://raw.githubusercontent.com/jotak/demo-mesh-arena/main/quickstart-naked.yml -n mesh-arena
```

2. Setup NAD 

```bash
# If you want to use another namespace, you need to update the NAD accordingly (namespace is referred to in "netAttachDefName")
kubectl apply -f https://raw.githubusercontent.com/netobserv/documents/main/examples/secondary-network/nad.yaml -n mesh-arena
```

NAD YAML:

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: l2-network
spec:
  config: |-
    {
      "cniVersion": "0.3.1", 
      "name": "my-l2-network", 
      "type": "ovn-k8s-cni-overlay", 
      "topology":"layer2", 
      "mtu": 1400, 
      "netAttachDefName": "mesh-arena/l2-network"
    }
```

3. Annotate the pods

```bash
kubectl edit deployment stadium-base -n mesh-arena
# In spec.template.metadata.annotation, add: "k8s.v1.cni.cncf.io/networks: l2-network"
kubectl edit deployment ball-base -n mesh-arena
# Same as above
```

4. Check interfaces

```bash
kubectl exec -it stadium-base-df878c486-nz6jz -- ip a
```

```
...
3: net1@if29: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1400 qdisc noqueue state UP 
    link/ether ca:e1:ce:b2:68:80 brd ff:ff:ff:ff:ff:ff
    inet6 fe80::c8e1:ceff:feb2:6880/64 scope link 
       valid_lft forever preferred_lft forever
```

```bash
kubectl exec -it ball-base-fd48b79db-v854q -- ip a
```

```
...
3: net1@if26: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1400 qdisc noqueue state UP 
    link/ether de:be:90:db:85:7a brd ff:ff:ff:ff:ff:ff
    inet6 fe80::dcbe:90ff:fedb:857a/64 scope link 
       valid_lft forever preferred_lft forever
```

5. Check pods definitions

```bash
kubectl get pods stadium-base-df878c486-nz6jz -ojsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}'
```

```
[{
    "name": "ovn-kubernetes",
    "interface": "eth0",
    "ips": [
        "10.131.0.23"
    ],
    "mac": "0a:58:0a:83:00:17",
    "default": true,
    "dns": {}
},{
    "name": "mesh-arena/l2-network",
    "interface": "net1",
    "mac": "ca:e1:ce:b2:68:80",
    "dns": {}
}]
```

6. Ping each other

```bash
# Mind the "%net1" after the IP
kubectl exec -it ball-base-fd48b79db-v854q -- ping -6 fe80::c8e1:ceff:feb2:6880%net1
```

```
PING fe80::c8e1:ceff:feb2:6880%net1 (fe80::c8e1:ceff:feb2:6880%3): 56 data bytes
64 bytes from fe80::c8e1:ceff:feb2:6880: seq=0 ttl=64 time=2.729 ms
64 bytes from fe80::c8e1:ceff:feb2:6880: seq=1 ttl=64 time=0.804 ms
64 bytes from fe80::c8e1:ceff:feb2:6880: seq=2 ttl=64 time=0.846 ms
64 bytes from fe80::c8e1:ceff:feb2:6880: seq=3 ttl=64 time=0.829 ms
```

7. Check in NetObserv

Install NetObserv - don't forget to set up privileged agents in order to get 2dary interfaces.
Also, when trying to find your ping traffic by filtering on protocol, remember this: ping on IPv6 uses ICMP_v6, not ICMP.

## Troubleshooting

In case of issues, you may get some info from the multus pods logs. Locate which node run your pod having issues, and the multus pod running on that node, and check its logs:

```bash
kubectl logs -n openshift-multus multus-x8jgt
```

```
I0305 09:06:30.774963    2931 event.go:364] Event(v1.ObjectReference{Kind:"Pod", Namespace:"mesh-arena", Name:"ball-base-fd48b79db-v854q", UID:"deabe709-54df-48d1-9f5b-58cb62532de6", APIVersion:"v1", ResourceVersion:"36569", FieldPath:""}): type: 'Normal' reason: 'AddedInterface' Add net1 [] from mesh-arena/l2-network
2026-03-05T09:06:30Z [verbose] ADD finished CNI request ContainerID:"01f476211c5fcaa70649d25d72a4a92a650d7d56fc3c41aa28b1ead3331b59c4" Netns:"/var/run/netns/e1aa8743-b185-4fe7-972f-e8611e7d0f84" IfName:"eth0" Args:"IgnoreUnknown=1;K8S_POD_NAMESPACE=mesh-arena;K8S_POD_NAME=ball-base-fd48b79db-v854q;K8S_POD_INFRA_CONTAINER_ID=01f476211c5fcaa70649d25d72a4a92a650d7d56fc3c41aa28b1ead3331b59c4;K8S_POD_UID=deabe709-54df-48d1-9f5b-58cb62532de6" Path:"", result: "{\"Result\":{\"cniVersion\":\"1.1.0\",\"interfaces\":[{\"mac\":\"3e:da:46:5e:e0:22\",\"name\":\"01f476211c5fcaa\"},{\"mac\":\"0a:58:0a:80:02:13\",\"name\":\"eth0\",\"sandbox\":\"/var/run/netns/e1aa8743-b185-4fe7-972f-e8611e7d0f84\"}],\"ips\":[{\"address\":\"10.128.2.19/23\",\"gateway\":\"10.128.2.1\",\"interface\":1}]}}", err: <nil>
2026-03-05T09:06:32Z [verbose] DEL starting CNI request ContainerID:"129bc834e656a5ab2b848a3a17cdfbeb5b6318e0ce03365f82ed0768aa8c2b26" Netns:"/var/run/netns/c847e6c7-8c53-472d-a4e0-9184fb0af676" IfName:"eth0" Args:"IgnoreUnknown=1;K8S_POD_NAMESPACE=mesh-arena;K8S_POD_NAME=ball-base-66586dc686-jxw6d;K8S_POD_INFRA_CONTAINER_ID=129bc834e656a5ab2b848a3a17cdfbeb5b6318e0ce03365f82ed0768aa8c2b26;K8S_POD_UID=63a4686a-0a87-4219-a790-701dd8b68afa" Path:""
2026-03-05T09:06:32Z [verbose] Del: mesh-arena:ball-base-66586dc686-jxw6d:63a4686a-0a87-4219-a790-701dd8b68afa:ovn-kubernetes:eth0 {"cniVersion":"0.4.0","name":"ovn-kubernetes","type":"ovn-k8s-cni-overlay","ipam":{},"dns":{},"logFile":"/var/log/ovn-kubernetes/ovn-k8s-cni-overlay.log","logLevel":"4","logfile-maxsize":100,"logfile-maxbackups":5,"logfile-maxage":0,"runtimeConfig":{}}
2026-03-05T09:06:32Z [verbose] DEL finished CNI request ContainerID:"129bc834e656a5ab2b848a3a17cdfbeb5b6318e0ce03365f82ed0768aa8c2b26" Netns:"/var/run/netns/c847e6c7-8c53-472d-a4e0-9184fb0af676" IfName:"eth0" Args:"IgnoreUnknown=1;K8S_POD_NAMESPACE=mesh-arena;K8S_POD_NAME=ball-base-66586dc686-jxw6d;K8S_POD_INFRA_CONTAINER_ID=129bc834e656a5ab2b848a3a17cdfbeb5b6318e0ce03365f82ed0768aa8c2b26;K8S_POD_UID=63a4686a-0a87-4219-a790-701dd8b68afa" Path:"", result: "", err: <nil>
```

Sometimes you may see errors such as NAD not found, etc.
