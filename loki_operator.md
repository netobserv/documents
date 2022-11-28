# Deploying NetObserv with the Loki Operator

This page provides a quick walk-through for setting up the Loki Operator with NetObserv. You can [find here more documentation](https://loki-operator.dev/docs/prologue/quickstart.md/) (or [there for OpenShift](https://docs.openshift.com/container-platform/4.11//logging/cluster-logging-loki.html)).

The Loki Operator integrates a [gateway](https://github.com/observatorium/api) that implements multi-tenancy & authentication with Loki for logging. However, NetObserv itself is not (yet) multi-tenant.

NetObserv requires to use a specific tenant for Loki, named `network`, which uses a specific tenant mode implemented in Loki Operator 5.6+. For that reason, NetObserv is not compatible with prior version of the Loki Operator.

Since 5.6 is not yet released, for testing purpose only you can use another tenant as a temporary hack. It shouldn't be used as such in production: in that case, we recommend to not use the Loki Operator, and use [Loki distributed deployment](./loki_distributed.md) instead.

## Installing Loki Operator

Install the Loki operator using Operator Hub. If using OpenShift, open the Console and navigate to Administrator view -> Operators -> OperatorHub.

Search for `loki`. You should find `Loki Operator` in `Red Hat` catalog.

Install the operator with the default configuration.

## Hack script

We provide a [hack script](./hack/loki-operator.sh) that uses AWS S3 storage, to run the steps described below. It assumes you have the AWS CLI installed with credentials configured. It will create a S3 bucket and configure Loki with it.

The first argument is the bucket name, second is the AWS region. Example:

```bash
./hack/loki-operator.sh netobserv-loki eu-west-1
```

If you choose to run it, you can ignore the following steps.

## Namespace

For simplicity, this guide assumes Loki is deployed in the same namespace as NetObserv.

If it doesn't already exist, create the `netobserv` namespace:

```bash
kubectl create ns netobserv
```

## External storage

Loki operator requires an external storage, such as Amazon S3. Check [the documentation](https://loki-operator.dev/docs/object_storage.md/) to set it up. Make sure you create the secret in `netobserv` namespace. Take note of the storage configuration you need to set in `LokiStack`, as mentioned in the linked documentation.

Example with AWS S3, using `aws` CLI:

```bash
S3_NAME="netobserv-loki"
AWS_REGION="eu-west-1"
AWS_KEY=$(aws configure get aws_access_key_id)
AWS_SECRET=$(aws configure get aws_secret_access_key)

aws s3api create-bucket --bucket $S3_NAME  --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION

kubectl create -n netobserv secret generic lokistack-dev-s3 \
  --from-literal=bucketnames="$S3_NAME" \
  --from-literal=endpoint="https://s3.${AWS_REGION}.amazonaws.com" \
  --from-literal=access_key_id="${AWS_KEY}" \
  --from-literal=access_key_secret="${AWS_SECRET}" \
  --from-literal=region="${AWS_REGION}"
```

## LokiStack

Then create a `LokiStack` in `netobserv` namespace. When using OpenShift, navigate to:

Administrator view -> Operators -> Installed Operators -> Loki Operator -> LokiStack -> Create LokiStack

- Name it `loki` (any name is fine, but you need to adapt the URLs below accordingly)
- Choose the size. While not suitable for production, `1x.extra-small` is OK for testing / demo. Note that very small clusters (e.g. 3 worker nodes) require `1x.extra-small`, see [troubleshooting](#troubleshooting) section below.
- Set `Object Storage` -> `Secret` as noted above.
- Set `Tenants Configuration` -> `Mode` to `openshift-network`. As a temporary hack, until `openshift-network` is available (expected in 5.6+), you can use `openshift-logging` instead. Just don't do that in production.

This will create `gateway`, `distributor`, `compactor`, `ingester`, `querier` and `query-frontend` components.

To allow `flowlogs-pipeline` to write to the gateway and `network-observability-plugin` to read from the gateway, you will need to create related `ClusterRole` and `ClusterRoleBinding` using:

```bash
kubectl apply -f examples/loki-stack/role.yaml
# or as a temporary hack until `openshift-network` tenant mode is available (expected in 5.6+), use "examples/loki-stack/role-hack.yaml" instead.
```

## NetObserv configuration

Once the Loki stack is up and running, you need to configure NetObserv to communicate to Loki through its `gateway` service. Loki CA certificate must have been written in a configmap, so it will be used for TLS.

Then you will be able to set the following configuration in `FlowCollector` for `network` tenant:

```yaml
  loki:
    url: 'https://loki-gateway-http.netobserv.svc:8080/api/logs/v1/network/'
    # temporary hack: for infrastructure tenant, use `url: 'https://loki-gateway-http.netobserv.svc:8080/api/logs/v1/infrastructure/'` instead
    statusUrl: 'https://loki-query-frontend-http.netobserv.svc:3100'
    tenantID: network
    # temporary hack: for infrastructure tenant, use `tenantID: infrastructure`
    authToken: HOST
    tls:
      enable: true
      caCert:
        type: configmap
        name: loki-ca-bundle
        certFile: service-ca.crt
```

## Troubleshooting

- Logs are by default `--log.level=warn`. 
You can set `--log.level=debug` in `gateway.go` and `opa_openshift.go` to get more logs.
// TODO: do the same without modifying code?

- AWS region not set for deploy-example-secret.sh
// TODO: not sure what this script is... In my hack script, region is passed as a parameter
If `aws configure get region` returns blank, the shell will fail. 
You can force region using `aws configure --region us-east-1` for example.

- Insufficient CPU or memory
If your pods hang in `Pending` state, you should double check their status using `oc describe`
We recommand to use size: 1x.extra-small but this still requires a lot of resources. 
You can decrease them in internal/manifests/internal/sizes.go and set `100m` for each CPUs and `256Mi` for each Memories
// TODO: do the same without modifying code? When extra-small is still too small, single nodes / kind?

- Certificate errors in Gateway logs
Check [ZeroSSL.com CA with acme.sh](./hack_dex.md#zerosslcom-ca-with-acmesh)
