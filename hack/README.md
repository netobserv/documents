# NetObserv hack scripts

## Scan NetObserv TLS endpoints

These scripts use [OpenShift tls-scanner](https://github.com/openshift/tls-scanner) to inspect TLS endpoints in an installed NetObserv deployment. The scan checks TLS 1.3 and ML-KEM readiness, then checks adherence to the cluster TLS profile. Port discovery does not depend on pod port declarations.

### Requirements

- An OpenShift cluster with NetObserv installed and an authenticated `oc` session.
- `jq`, `git`, and Docker or Podman on the local machine.
- A registry that the cluster can pull from, and permission to push images to it.
- Cluster permissions to create temporary Jobs, NetworkPolicies, and cluster RBAC, including permission to grant the scanner ServiceAccount use of the privileged SCC.

### Build and push the scanner image

Set `TLS_SCANNER_IMAGE` to an image name in a registry the cluster can access. The helper checks out a pinned upstream scanner revision, builds its `Dockerfile.local`, and pushes the image:

```sh
TLS_SCANNER_IMAGE=quay.io/my-namespace/tls-scanner:dev \
  ./hack/tls-scanner-image.sh
```

The helper uses Podman by default. Set `OCI_BIN=docker` to use Docker. Set `TLS_SCANNER_REF` to choose another upstream revision, `TLS_SCANNER_PLATFORM` to change the build platform (default `linux/amd64`), or `TLS_SCANNER_SOURCE` to build an existing local scanner source directory as-is.

Authenticate to your registry with the selected container tool before pushing.

### Run the scan

```sh
TLS_SCANNER_IMAGE=quay.io/my-namespace/tls-scanner:dev \
TLS_SCANNER_OPERATOR_NAMESPACE=openshift-netobserv-operator \
  ./hack/tls-scan.sh
```

By default, the Job runs in `netobserv` and scans `netobserv`, `netobserv-privileged`, and the operator namespace. Set `TLS_SCANNER_NAMESPACE` if the Job should run elsewhere, and `TLS_SCANNER_OPERATOR_NAMESPACE` to the namespace containing the operator. Set `TLS_SCANNER_NAMESPACES` to a comma-separated list to change the scan scope.

Each run creates a timestamped directory under `out/tls-scanner/`, containing a Markdown report, JSON, CSV, JUnit, and logs. The latest artifacts are copied to `out/tls-scanner/`, with TLS profile adherence artifacts under `adherence/`. The script removes the temporary Job, ServiceAccount, RBAC resources, and NetworkPolicies after collecting results. It does not change NetObserv workloads.

The scan requires ingress access from the temporary scanner Job to the operator and NetObserv pods. The script creates temporary NetworkPolicies for that access and deletes them during cleanup. Review `NO_TLS`, `FILTERED`, and `NO_PORTS` results because network policies or pod security restrictions can prevent the scanner from reaching a TLS endpoint. Either scan returning a nonzero exit code makes the script return failure.

The job namespace, output directory, parallelism, and timeout can be configured with `TLS_SCANNER_NAMESPACE`, `TLS_SCANNER_OUTPUT_DIR`, `TLS_SCANNER_PARALLEL`, and `TLS_SCANNER_TIMEOUT_SECONDS`.
