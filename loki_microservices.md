# Scalable loki deployment

This document aims to design the deployment of a scalable version of Loki for testing purposes. This is based on [microservice mode](https://grafana.com/docs/loki/next/fundamentals/architecture/deployment-modes/#microservices-mode). 

This requires [external storage to save chunks](https://grafana.com/docs/loki/latest/storage/#implementations---chunks). For a deployment without external storage, check [loki simple doc](./loki_simple.md).

## Hack script

A [hack script](./hack/loki-microservices.sh) is provided for convenience. It assumes you have the AWS CLI installed with credentials configured. It will create a S3 bucket and configure Loki with it.

The first argument is the bucket name, second is the AWS region. Example:

```bash
./hack/loki-microservices.sh netobserv-loki eu-west-1
```

For a step-by-step installation instead of this hack script, read the next sections.

## Folders content

You can go to the next sections to understand the configuration of this stack or directly go to [deploy section](##Deploy).

### 1 - Prerequisites

To run this stack you will need to configure: 
- a [service account](./examples/loki-microservices/1-prerequisites/service-account.yaml) used for deployments and statefulSets
- a [configMap](./examples/loki-microservices/1-prerequisites/config.yaml) containing loki configuration used in each component

### 2 - Components

The following components will be generated:
- Deployments:
  - [distributor](./examples/loki-microservices/2-components/distributor-deployment.yaml)
  - [query front end](./examples/loki-microservices/2-components/query-frontend-deployment.yaml)
- StatefulSets:
  - [ingester](./examples/loki-microservices/2-components/ingester-statefulset.yaml)
  - [querier](./examples/loki-microservices/2-components/querier-statefulset.yaml)
These statefulSets uses `volumeClaimTemplates` that create a `PersistentVolumeClaim` for each pod.

By default, you will get 2 pods of each component. You can change this number updating the `replicas` section of each yaml file independently.

Check [official architecture documentation](https://grafana.com/docs/loki/next/fundamentals/architecture/components/) for more details.
![loki architecture representation](https://grafana.com/docs/loki/next/fundamentals/architecture/loki_architecture_components.svg)

### 3 - Services

Related services will be created for each components.
Note that `querier` and `ingester` has alternative services with `-headless` suffix. These services uses `clusterIP: None` parameter. No load balancing will be done using these since client usually use first IP returned by the DNS record. This can be usefull to list available IPs for each component.

An additionnal service called `loki-microservices-memberlist` will match all the components and allow discoverability between them.

## Storage configuration
Edit [loki Secret](./examples/loki-microservices/1-prerequisites/secret.yaml) and replace `ACCESS_KEY_ID` and `SECRET_ACCESS_KEY` values with your bucket credentials. These will be loaded in environment variables and can be reused in config as `${ACCESS_KEY_ID}` and `${SECRET_ACCESS_KEY}`.

Edit [loki ConfigMap](./examples/loki-microservices/1-prerequisites/config.yaml) and replace `$(LOKI_STORE_NAME)` and `$(LOKI_STORE)` with your proper external storage configuration.

Example using `s3` bucket called `loki` in `us-east-1` region with credentials from secret:
```yaml
  config.yaml: |
    ...
    common:
      storage:
        s3:
          s3: https://s3.us-east-1.amazonaws.com
          bucketnames: loki
          region: us-east-1
          access_key_id: ${ACCESS_KEY_ID}
          secret_access_key: ${SECRET_ACCESS_KEY}
          s3forcepathstyle: true
    ...
    schema_config:
      configs:
        - ...
          object_store: s3
```

Check [official examples](https://grafana.com/docs/loki/latest/storage/#examples).

/!\ Without external storage, components will not share the chunks and querier will crash as soon as cache is cleared /!\
## Deploy

Ensure [storage configuration](#storage-configuration) is up to date.
Run the following command to apply all yamls at once in `netobserv` namespace:
`kubectl apply -f ./examples/loki-microservices/ -n netobserv --recursive`

This will create all the components and services described above.

## Destroy

Delete everything by running:

```bash
kubectl delete --recursive -f ./examples/loki-microservices
```

## Network Observability Operator

To connect NOO with this config, you will have to update the `loki` section with the following urls assuming you used `netobserv` namespace:

```yaml
  loki:
    mode: Microservices
    microservices:
      ingesterUrl: 'http://loki-microservices-distributor.netobserv.svc.cluster.local:3100/'
      querierUrl: 'http://loki-microservices-query-frontend.netobserv.svc.cluster.local:3100/'
```
