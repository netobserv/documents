# Deploying NetObserv with the Loki Operator

This page provides a quick walk-through for setting up the Loki Operator with NetObserv. You can [find here more documentation](https://loki-operator.dev/docs/prologue/quickstart.md/) (or [there for OpenShift](https://docs.openshift.com/container-platform/4.11//logging/cluster-logging-loki.html)).

The Loki Operator integrates a [gateway](https://github.com/observatorium/api) that implements multi-tenancy & authentication with Loki for logging. However, NetObserv itself is not (yet) multi-tenant.

NetObserv requires to use a specific tenant for Loki, named `network`, which uses a specific tenant mode implemented in Loki Operator 5.6+. For that reason, NetObserv is not compatible with prior version of the Loki Operator.

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
- Choose the size. While not suitable for production, `1x.demo` is OK for testing / demo (or `1x.extra-small` in operator 5.7). Note that very small clusters (e.g. 3 worker nodes) require `1x.demo`, see [troubleshooting](#troubleshooting) section below.
- Set `Object Storage` -> `Secret` as noted above.
- Set `Tenants Configuration` -> `Mode` to `openshift-network`.

This will create `gateway`, `distributor`, `compactor`, `ingester`, `querier` and `query-frontend` components.

## NetObserv configuration

Once the Loki stack is up and running, you need to configure NetObserv to communicate to Loki through its `gateway` service:

```yaml
  loki:
    mode: LokiStack
    lokiStack:
      name: loki
```

### User access

You then need to define `ClusterRoleBindings` for allowed users or groups, such as [this one](./examples/loki-stack/rolebinding-user-test.yaml) for a user named `test`. This can also be done from the CLI:

```bash
oc adm policy add-cluster-role-to-user netobserv-reader test
```

Cluster admins do not need this role binding.

### Testing multi-tenancy

Using the loki-operator 5.7 (or above) + FORWARD mode allows multi-tenancy, meaning that in this mode, user permissions on namespaces are enforced so that users would only see flow logs from/to namespaces that they have access to. You don't need any extra configuration for NetObserv or Loki. Here's a suggestion of steps in order to test it in OpenShift:

- Install Loki Operator + NetObserv as mentioned above.
- If you haven't created a project-admin user yet:
  - In ocp console, go to "Users management" > "Users" and click on "Add IDP". For a quick test you can use a "Htpasswd" type
  - E.g. set as content: `test:$2y$10$Z2CXWdNCkp6rvoR5bmbI8OyiTYsUreOMn6sV2UNzpl9c1Eb1vBqO.` which stands for user `test` / `test`.
- Wait a few seconds or minutes that the IDP is working, then login (e.g. in browser incognito mode - you should see the new htpasswd option from the login screen)
- Create a new project named "test" from this session. By doing so, the user is a project-admin on that namespace.
- Deploy some workload in this namespace that will generate some flows (you don't need to do so as the test user - doing so as a cluster admin works as well)
  - E.g. `kubectl apply -f https://raw.githubusercontent.com/jotak/demo-mesh-arena/main/quickstart-naked.yml -n test`
- In the admin perspective, a new "Observe" menu should have appeared, with "Network Traffic" as the only page. Go to Network Traffic.
- You should see an error (403). It's expected: the user needs to have explicit permission to get flows.
  - Apply the role binding: `oc adm policy add-cluster-role-to-user netobserv-reader test`
- Refresh the flow logs: you should see traffic, limited to the allowed namespace.

## Troubleshooting

- Logs are by default `--log.level=warn`. 
You can set `--log.level=debug` in `gateway.go` and `opa_openshift.go` to get more logs.

- AWS region not set for deploy-example-secret.sh
If `aws configure get region` returns blank, the shell will fail. 
You can force region using `aws configure --region us-east-1` for example.

- Insufficient CPU or memory
If your pods hang in `Pending` state, you should double check their status using `oc describe`
We recommand to use size: 1x.extra-small but this still requires a lot of resources. 
You can decrease them in internal/manifests/internal/sizes.go and set `100m` for each CPUs and `256Mi` for each Memories

- Certificate errors in Gateway logs
Check [ZeroSSL.com CA with acme.sh](./hack_dex.md#zerosslcom-ca-with-acmesh)

- Running custom Loki query bypassing the gateway:

```bash
oc exec -it netobserv-plugin-d894b4544-97tq2 -- curl --cert /var/loki-status-certs-user/tls.crt  --key /var/loki-status-certs-user/tls.key  --cacert /var/loki-status-certs-ca/service-ca.crt -k -H "X-Scope-OrgID: network"  https://loki-query-frontend-http:3100/loki/api/v1/label/DstK8S_Namespace/values
```

### Loki "input size too long" error

This error is generally seen when non cluster-admin users have access to many namespaces. Since the operator gateway will inject namespaces in queries for
multi-tenancy, this may result in queries being too long, reaching 5120 characters (which sounds actually like a very reasonable limit for non-cluster-admin users), and thus being rejected by Loki.

#### For cluster admins

Users identified as cluster admins should not see this error because there is no namespace-based restriction for them. The Loki operator performs this identification by **checking if users belong to one of the defined cluster-admin groups**.

Note that having the cluster-admin **role** does not imply belonging to the cluster-admin **group**. So you should double-check groups.

With OpenShift, to create a cluster-admin group, run:

```bash
oc adm groups new cluster-admin
```

To add a user to cluster-admin group, run:

```bash
oc adm policy add-cluster-role-to-user cluster-admin <username>
```

You may also want to give cluster-admin role for all group members rather than one by one:

```bash
oc adm policy add-cluster-role-to-group cluster-admin cluster-admin
```

Running these commands should solve the problem. It might be necessary to wait a couple of minutes for changes to be effective.

By default, the Loki operator recognizes three groups as cluster-admins: `system:cluster-admins`, `cluster-admin` and `dedicated-admin`. If you already have a cluster admin group with a different name, you can override this default in the `LokiStack` configuration:

```yaml
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: loki
  namespace: netobserv
spec:
  # ... other settings here ...
  tenants:
    mode: openshift-network
    openshift:
      adminGroups: 
      - my-admins-group
```

#### For non cluster admins

In most cases, non cluster admins shouldn't see this error as the configured input size limit should be long enough. However, it may still occur than users have access to many namespaces despite not being cluster admins. You may create a new group for these users, and configure the `LokiStack` tenant as shown above.

We are also working on an alternative to allow finer-grained RBAC access to NetObserv flows, which would allow to restrict accessible namespaces per user. This is being tracked [here](https://issues.redhat.com/browse/NETOBSERV-1324).
