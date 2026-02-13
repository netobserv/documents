# NetObserv: community roadmap

NetObserv is an open-source project with upstream / community releases, and downstream / product releases often referred to as "Network Observability for OpenShift", which is a Red Hat product.

This section describes a roadmap specifically for the upstream project. Improvements targeting downstream are not listed here, even though they will also benefit to the upstream. The maintainers team uses GitHub issues for community-driven tasks, and a partially public [JIRA tracker](https://issues.redhat.com/projects/NETOBSERV/) for product-driven tasks.

## Milestone: production-readiness

### Current status

Production-readiness is not equivalent between the upstream and the downstream versions. The downstream product is production-ready and actually deployed in production. A gap exists with the community releases, which this roadmap precisely aims to address. To date, deploying the community releases to production should be considered with care.

### Next steps

#### Security by default

- It is currently up to the users to create Network Policies that will restrict the access from and to the NetObserv namespaces. It should be noted that the NetObserv operator *does* embed an optional network policy for that purpose, however it has some known issues with CNIs other than OVN-Kubernetes (and possibly unknown issues as well).

- The default "Service" deployment model requires to manually configure TLS or mTLS between NetObserv components, or to disable TLS. The "Kafka" mode (which is not default) can also be configured manually with mTLS. Using Strimzi and KafkaUser make it rather straightforward, though that's still not a default.

*Why it differs from downstream:*

When the OVN-Kubernetes CNI is detected, which is the default in OpenShift, a network policy is deployed by default, restricting the access from and to the NetObserv namespaces. Additionally, the default "Service" deployment model uses TLS, automatically configured based on OpenShift serving certificates feature.

*Actions to take:*

- Network policies
  - Investigate on the network policy issues, make it work for some common CNIs.
  - Raise warnings / degrade conditions when no network policy is detected.
  - Better document the required ACLs for NetObserv, for users using CNIs that don't support the embedded policy.
  - Document the risks associated to not having a network policy.
- TLS / mTLS
  - Integrate Trust-manager resources in the Helm chart by default ([issue #2360](https://github.com/netobserv/network-observability-operator/issues/2360)).
  - Raise warnings / degrade conditions when no TLS is detected.
  - Document the risks associated to disabling TLS.
- Documentation review
  - Review all the documentation to emphasize more the risks when relaxing the secured defaults (e.g.: privileged agent).

#### Securing the upstream build and release processes

Upstream builds and releases are done through GitHub worklows. The workflow generates OCI images, which are pushed to quay.io.

Releases are triggered by a git tag, and resulting images are pushed as well to quay.io. The community release process is described [here](https://github.com/netobserv/network-observability-operator/blob/main/RELEASE.md). Some manual steps are involved to publish the Helm chart.

This process is functional but lacks some features to make it really safe for production. OCI images are not signed, and no SBOM is generated.

*Why it differs from downstream:*

Downstream builds and releases use an entirely different workflow that is common across many Red Hat products, using [Konflux](https://konflux-ci.dev/docs/), with the highest security standards. It produces not a Helm chart, but an OLM bundle.

*Actions to take:*

- Release process improvement
  - Generate SBOM
  - Sign images
  - Make releases immutable
  - Automate the Helm chart generation
