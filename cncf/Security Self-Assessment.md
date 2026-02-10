# NetObserv Self-Assessment

Security reviewers: Joël Takvorian

This document is the Security Self-Assessment required for CNCF sandbox projects.

## Table of Contents

* [Metadata](#metadata)
  * [Security links](#security-links)
* [Overview](#overview)
  * [Actors](#actors)
  * [Actions](#actions)
  * [Background](#background)
  * [Goals](#goals)
  * [Non-goals](#non-goals)
* [Self-assessment use](#self-assessment-use)
* [Security functions and features](#security-functions-and-features)
* [Project compliance](#project-compliance)
* [Secure development practices](#secure-development-practices)
* [Security issue resolution](#security-issue-resolution)
* [Appendix](#appendix)

## Metadata

### Software

- https://github.com/netobserv/network-observability-operator
- https://github.com/netobserv/flowlogs-pipeline
- https://github.com/netobserv/netobserv-ebpf-agent
- https://github.com/netobserv/network-observability-console-plugin
- https://github.com/netobserv/network-observability-cli

### Security Provider?

No.

### Languages

- Go
- TypeScript
- C (eBPF)
- Bash

### Software Bill of Materials

SBOM of downstream builds are publicly available (e.g. https://quay.io/repository/redhat-user-workloads/ocp-network-observab-tenant/network-observability-operator-ystream, see .sbom suffixed tags). While upstream builds don't have SBOM attached, they should be mostly identical, as upstream and downstream builds share the same code and base images. Minor differences should be expected though.

### Security Links

TODO

## Overview

NetObserv is a set of components used to observe network traffic by generating NetFlows from eBPF agents, enriching those flows with Kubernetes metadata, exporting them in various ways (logs, metrics, Kafka, IPFIX...), and finally providing a comprehensive visualization tool for making sense of that data, a network health dashboard, and a CLI. Those components are mainly designed to be deployed in Kubernetes via an integrated Operator.

### Background

Kubernetes can be complex, and so does Kubernetes networking. Especially as it can differ from a CNI to another. Cluster admins often find important to have a good observability over the network, that clearly maps with Kubernetes resources (Services, Pods, Nodes...). This is what NetObserv aims to offer. Additionally, it aims at identifying network issues, and raising alerts. While it is not designed as a security tool, the data that it provides can be leveraged, for instance, to detect network threat patterns.

### Actors

1. The [operator](https://github.com/netobserv/network-observability-operator), orchestrates the deployment of all related components (listed below), based on the supplied configuration. It operates at the cluster scope.
2. The [eBPF agent](https://github.com/netobserv/flowlogs-pipeline) and [flowlogs-pipeline](https://github.com/netobserv/flowlogs-pipeline) are collecting network flows from the hosts (nodes), processing them, before sending them to storage or custom exporters.
3. The [web console](https://github.com/netobserv/network-observability-console-plugin) reads data from the stores to display dashboards.
4. The [CLI](https://github.com/netobserv/network-observability-cli) is an independent piece that also starts the eBPF agents and flowlogs-pipeline for on-demand monitoring, from the command line.

### Actions

The operator reads the main configuration (FlowCollector CRD) to determine how to deploy and configure the related components.

The eBPF agents are deployed, one per node (DaemonSet), with elevated privleges, load their eBPF payload in the host kernel, and start collecting network flows. Those flows are sent to flowlogs-pipeline, which correlate them with Kubernetes resources, and performs various transformations, before sending them to a log store (Loki) and/or expose them as Prometheus metrics. Other exporting options exist. Loki, Prometheus and any receiving system are not part of the NetObserv payload, they must be installed and managed separately.

Optionally, Apache Kafka can be used as an intermediate between the eBPF agents and flowlogs-pipeline.

The web console fetches the network flows from the stores (Loki and/or Prometheus) to display dashboards. It does not connect directly to other NetObserv components.

The architecture is described more in details [here](https://github.com/netobserv/network-observability-operator/blob/main/docs/Architecture.md), with diagrams included.

### Goals

NetObserv intends to provide visibility on the cluster network traffic, and to help troubleshooting network issues.

In terms of security, because the NetObserv operator has cluster-wide access to many resources, and because the eBPF agents have elevated privileges on nodes, both of them must not be accessible by non-admins.

Additionally, NetObserv MUST NOT

- Leak any network data or metadata to unauthorized users.
- Cause any harm by being gamed when reading network packets (untrusted).
- Allow connections from untrusted workloads to flowlogs-pipeline.

### Non-Goals

- Enforce RBAC when querying backend stores: this is the responsibility of the components that manage those stores (e.g. the Loki Operator comes with a Gateway that enforces RBAC; NetObserv connects to that Gateway).

## Self-assessment Use

This self-assessment is created by the NetObserv team to perform an internal analysis of the project's security. It is not intended to provide a security audit of NetObserv, or function as an independent assessment or attestation of NetObserv's security health.

This document serves to provide NetObserv users with an initial understanding of NetObserv's security, where to find existing security documentation, NetObserv plans for security, and general overview of NetObserv security practices, both for development of NetObserv as well as security of NetObserv.

This document provides NetObserv maintainers and stakeholders with additional context to help inform the roadmap creation process, so that security and feature improvements can be prioritized accordingly.

## Security functions and features

| Component                 | Applicability    | Description of Importance                                                         |
| ------------------------- | ---------------- | --------------------------------------------------------------------------------- |
| Namespace segregation     | Critical         | For hardened security, the components that require elevated privileges are deployed in their own namespace, flagged as privileged, that should be only accessible by cluster admins. |
| Non-root eBPF agents      | SecurityRelevant | Whenever possible, the eBPF agents run with fine-grained privileges (e.g. CAP_BPF) instead of full privileges. Some features, however, do require full privileges. |
| Network policies          | SecurityRelevant | A network policy can be installed automatically to better isolate the communications of the NetObserv workloads. However, due to policies being somewhat CNI-dependent and the inherent risk of breaking communications with untested CNIs, this feature is not enabled by default, except in OpenShift. |
| Encrypted traffic         | SecurityRelevant | All servers are configured with TLS by default. |
| Authorized traffic (mTLS) | SecurityRelevant | Traffic between the eBPF agents and flowlogs-pipeline can be authorized on both sides (mTLS) when using with Kafka. It is planned to bring mTLS to other modes, without Kafka. When not using mTLS, it is highly recommended to protect the netobserv namespace with a network policy. |
| RBAC-enforced stores      | SecurityRelevant | Multi-tenancy can be achieved when supported by the backend stores: e.g. Loki with the Loki Operator, Prometheus with Thanos. In that case, NetObserv can be configured to forward user tokens. |

## Project Compliance

N/A: the project has not been evaluated against compliance standards as of today.

### Future State

Compliance can be evaluated based on demand.

## Secure Development Practices

A high security standard is observed, enforced by company policy (Red Hat).

### Deployment Pipeline

In order to secure the SDLC from development to deployment, the following measures are in place:

- Branch protection on the default (`main`) branch, and release branches (`release-*`):
  - Require a pull request before merging
    - Require approvals: 1
    - Dismiss stale pull request approvals when new commits are pushed
    - Require review from Code Owners
  - Require status checks to pass before merging
    - Build, linting, tests, clean state checks must pass
    - In the eBPF agent, BPF bytecode is verified
  - Force-push not allowed
- Code owners need to have 2FA enabled.
- Vulnerabilities in dependencies, and dependency upgrades, are managed via Dependabot and Renovate.
- Some weaknesses are reported by linters (golangci-lint, eslint).
  - `govulncheck` use to be added to the roadmap.
- Downstream release process is automated.
  - It includes vulnerability scans, FIPS-compliance checks, immutable images, SBOM, signing.
- Upstream release process is partly automated (the helm chart bundling is not, at this time).
  - More security measures to be added to the roadmap.

### Communication Channels

- Internal communications among NetObserv maintainers working at Red Hat happen in private Slack channels.
- Communications with maintainers external to Red Hat happen in the public Slack channel (`#netobserv-project` on http://cloud-native.slack.com/).
- Inbound communications are accepted through that same channel, or through GitHub Issues, or the GitHub discussion pages.
- Outbound messages to users can be made via documentation, release notes, blogs, social media and the public slack channel.

## Security Issue Resolution

As a Red Hat product, security issues and procedures are described on the [Security Contacts and Procedures](https://access.redhat.com/security/team/contact/?extIdCarryOver=true&sc_cid=701f2000001Css5AAC) page.

### Responsible Disclosure Practice

The same page mentioned above describes the Responsible Disclosure Practice. An email should be send to the Red Hat Product Security team, who will engage the discussion with the project maintainers, and respond to the reporter.

### Incident Response

In the event that a vulnerability is reported, the maintainer team, the Red Hat Product Security team and the reporter will collaborate to determine the validity and criticality of the report. Based on these findings, the fix will be triaged and the maintainer team will work to issue a patch in a timely manner.

Patches will be made to the `main` and the latest release branches, and new releases (upstream and downstream) will be triggered. Information will be disseminated to the community through all appropriate outbound channels as soon as possible based on the circumstance.

## Appendix

- Known Issues Over Time
  - Known issues are currently tracked in the project roadmap. There are currently no known vulnerabilities in the current supported version.
- OpenSSF Best Practices
  - The process to get a Best Practices badge is not yet on the roadmap.
- Case Studies
  - TBC
- Related Projects / Vendors
  - Similar to: Cilium Hubble, Pixie, Microsoft Retina. A differentiator is that NetObserv is fully open-source, CNI-independent, and actively maintained. It has some unique features, such as its FlowMetrics API. It also tries to differentiate with a polished UX.
