# Hacks on Loki & Grafana
This file will help you using [loki-operator](https://github.com/ViaQ/loki-operator) since it's still WIP project.
You can check [this PR](https://github.com/ViaQ/loki-operator/pull/99) for dev usage and the [README.md](https://github.com/ViaQ/loki-operator/blob/master/README.md) file for status

## Fake Loki frontend
If you only need basic http endpoints with fake datas from [grafana examples](https://grafana.com/docs/loki/latest/api/#grafana-loki-http-api), you can create a fake server using [json-server](https://github.com/typicode/json-server).

Install json-server globally:
```bash
sudo npm install -g json-server
```

Run the server on `http://localhost:3100`:
```bash
json-server --watch ./examples/loki_api_examples.json --routes ./examples/routes.json --port 3100 --delay 100
```

This will expose routes from [routes.json](./examples/routes.json) with [loki_api_examples.json](./examples/loki_api_examples.json) datas. 
You can also use [loki_api_custom.json](./examples/loki_api_custom.json) instead for OpenShift real sample datas.

## Loki Operator without gateway
Loki operator can be run without gateway for debug on kind or Openshift. It will create the same ressources as helm lokistack installation:
`distributor`, `compactor`, `ingester`, `querier`, `query-frontend`

Check [loki components](https://grafana.com/docs/loki/latest/fundamentals/architecture/#components) before getting started.

### Requirements
- Install kubectl CLI for communicating with the cluster.
- Running Kubernetes cluster using kind.
- A container registry that you and your Kubernetes cluster can reach.

### From Sources

Clone loki-operator repository and open folder
```bash
git clone https://github.com/ViaQ/loki-operator.git
cd loki-operator
```

Disable loki auth for development in [loki-config.yaml](https://github.com/ViaQ/loki-operator/blob/master/internal/manifests/internal/config/loki-config.yaml#L2)
```bash
sed -i 's/auth_enabled: true/auth_enabled: false/g' internal/manifests/internal/config/loki-config.yaml
```

Build and push the container image and then deploy the operator
```bash
make oci-build oci-push deploy REGISTRY_ORG=netobserv VERSION=latest
```

Create a LokiStack instance to get the various components of Loki up and running
```bash
kubectl apply -f hack/lokistack_dev.yaml
```

This will create `distributor`, `compactor`, `ingester`, `querier` and `query-frontend` components.

## Loki Operator on Openshift with gateway

Content moved to [loki_operator.md](./loki_operator.md).

## Loki & Grafana stack with Helm

Deploy [loki and grafana](https://grafana.com/docs/loki/latest/installation/helm/#deploy-grafana-to-your-cluster) to your cluster from official images using helm
```bash
helm upgrade --install loki grafana/loki-stack --set promtail.enabled=false
helm install loki-grafana grafana/grafana
```

Wait for the service running then forward port
```bash
kubectl port-forward service/loki-grafana 3000:80
```

Login : `admin`
Password should be retreive with :
```bash
kubectl get secret loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

### Troubleshooting
If loki-grafana deployment fails with following error on OpenShift:
Error creating: pods "loki-grafana-XXXXXXXXXX" is forbidden: unable to validate against any security context

Simply run:
```bash
oc adm policy add-scc-to-user anyuid -z loki
oc adm policy add-scc-to-user anyuid -z loki-grafana
```

## Grafana
If you installed loki using the operator, you will not have grafana installed. You may need to install it to make queries and dashboards but it's not mandatory to make loki work.

### From Image with oauth
Create [grafana instance](https://grafana.com/docs/grafana/latest/installation/kubernetes/) from official image.
Update `examples/grafana.ini` configuration and run:
```bash
kubectl create configmap grafana-config --from-file=examples/grafana.ini
kubectl apply -f examples/grafana.yaml
```

Wait for the service running then forward port
```bash
kubectl port-forward service/grafana 3000:3000
```

OR 

Use route at `http://grafana-default.apps.<MY_CLUSTER_URL>`

Login : `admin`
Password : `admin`
Info : You can skip password definition or change it at first login

### From Openshift OperatorHub
Grafana operator is available on OperatorHub. Open your Openshift Administrator Console and go to:
    Operators -> OperatorHub
    Search for 'grafana'
    Install it using default options in default namespace for example
    *This can take some minutes*

Then go to:
    Operators -> Installed Operators
    Select grafana-operator
    Click on `Create Instance` in the Grafana Provided API card
    *This can take some minutes*

This will create a grafana instance with a route available in:
    Networking -> Routes

Login : `root`
Password : `secret`

You can follow this [blog post](https://www.redhat.com/en/blog/custom-grafana-dashboards-red-hat-openshift-container-platform-4) for more details

## Grafana Usage

Open http://localhost:3000/ and login with `admin` + password according to previous sections

Select "add datasource" => "Loki" and set your source :
- `http://loki:3100` for helm
- `http://loki-query-frontend-http-lokistack-dev.default.svc.cluster.local:3100` for loki-operator without gateway
- `lokistack-gateway-http-lokistack-dev.openshift-logging.svc.cluster.local:8080/api/logs/v1/tenant-a` for loki-operator with gateway enabled using `tenant-a` endpoint. 
  Check `Forward Oauth Identity` option to send `X-Forwarded-User` according to [grafana.ini](./examples/grafana.ini)

You should get "Data source connected and labels found." after clicking Save & Test button

Example of queries for `netobserv-flowcollector` app:
- View raw logs:
`{app="netobserv-flowcollector"}`

- Top 10 sources by volumetry (1 min-rate):
`topk(10, (sum by(SrcWorkload,SrcNamespace) ( rate({ app="netobserv-flowcollector" } | json | __error__="" | unwrap Bytes [1m]) )))`

- Top 10 destinations for a given source (1 min-rate):
`topk(10, (sum by(DstWorkload,DstNamespace) ( rate({ app="netobserv-flowcollector",SrcNamespace="default",SrcWorkload="goflow" } | json | __error__="" | unwrap Bytes [1m]) )))`