## Contributing to the NetObserv projects

These contribution guidelines apply to all projects / repositories in the [netobserv organization](https://github.com/netobserv/). Almost the source code is licensed under [Apache v2.0](https://www.apache.org/licenses/LICENSE-2.0.html), with the exception of our [BPF code](https://github.com/netobserv/netobserv-ebpf-agent/blob/e3089669f1fbc91cf56a19e190f5aa8d29aaa4ba/bpf/flows.c#L303) which is GPL.

Contributions can take the shape of pull requests for documentation or code change, providing feedback, opening bug reports or even [writing blog posts](https://github.com/netobserv/netobserv.github.io). They are always welcome! For large changes, it is recommended to [start a discussion](https://github.com/netobserv/netobserv-operator/discussions/new/choose) prior to opening a pull request. Or as an alternative, you can reach out to the team on the CNCF slack channel [#netobserv-project](http://cloud-native.slack.com/) (to create an account, get an invite from https://slack.cncf.io/).

There should be mutual respect between contributors and maintainers.

### Security vulnerabilities

Unlike other contributions, if you think you discovered a security vulnerability, please do not report it publicly or even fix it publicly. Please follow the instructions described in the [GitHub private reporting process](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/privately-reporting-a-security-vulnerability) instead.

### Documentation contributions

Upstream (community) documentation can be found in their respective component repositories, either in the main README or in their `docs` directories. For example:

- [Operator README](https://github.com/netobserv/netobserv-operator/blob/main/README.md)
- [Operator metrics documentation](https://github.com/netobserv/netobserv-operator/blob/main/docs/Metrics.md)
- [eBPF agent README](https://github.com/netobserv/netobserv-ebpf-agent/blob/main/README.md)
- [eBPF agent architecture](https://github.com/netobserv/netobserv-ebpf-agent/blob/main/docs/architecture.md)
- etc.

For the documentation related to the downstream OpenShift product ([Network Observability](https://docs.openshift.com/container-platform/latest/observability/network_observability/netobserv-operator-release-notes.html)), you should follow the specific [OpenShift documentation guidelines](https://github.com/openshift/openshift-docs/blob/main/CONTRIBUTING.adoc). Still, don't hesitate to [get in touch with the team](https://github.com/netobserv/netobserv-operator/discussions) first.

### Code contributions

Code contributions are very welcome. As said, it's recommended to have a discussion prior to doing any large change. When adding a new feature, we need to understand which use case it is going to solve, and assess whether that is something the core development team is going to maintain in the long run, or if the maintenance can be delegated.

If you don't really know where to start among the different repositories, take a look at the [architecture](https://github.com/netobserv/netobserv-operator/blob/main/docs/Architecture.md) document: it should guide you through the components. You can also [open a discussion](https://github.com/netobserv/netobserv-operator/discussions/new/choose).

We use GitHub's pull request system to merge contributions. The process is:

- You [fork](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo) one or more of the repositories with your GitHub account
- You make changes, build and test them (the build process should be described in the respective repositories - contact us if you need help)
- Once you are happy with them, you can push them to your fork and [open a pull-request](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/creating-a-pull-request)
  - If you don't think the PR is ready but still would like to get some early discussion, you can open a [draft PR](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests#draft-pull-requests).
- The changes should start being reviewed within a week. If that's not the case, don't hesitate to mention any of the maintainers in your PR. Maintainers are listed in the [OWNERS file](https://github.com/netobserv/netobserv-operator/blob/main/OWNERS).
- There probably will be some back and forth discussion during the review process. You may be asked to change some parts of your code as a result. New changes should be added as new commits rather than amending / squashing the commits, so that reviewers can focus on the new diffs. Sometimes you may also have to rebase it.
- As part of the continuous integration, there are some automated checks that will be executed in the PR. In general we want all of them to pass, however and unfortunately, some of them aren't 100% reliable and might fail for reasons unrelated to your changes. As a rule of thumb, the GitHub action checks (with the GitHub icon) are reliable and should always pass. If they don't, you probably broke something. If other checks don't pass, don't worry too much, the maintainers will check if it's ok anyway or not.
- When you and the reviewers consider the PR is ready, it can finally be merged. Commits will be squashed in a single one (unless exception), then merged into the `main` branch.

### AI-Assisted Contributions Policy

1. You **MAY** use AI assistance for contributing to NetObserv, as long as you follow the principles described below.

2. **Accountability**: You **MUST** take the responsibility for your contribution. Contributing to NetObserv means vouching for the quality, license compliance, and utility of your submission. All contributions, whether from a human author or assisted by large language models (LLMs) or other generative AI tools, must meet the project’s standards for inclusion. The contributor is always the author and is fully accountable for the entirety of these contributions.

3. **Transparency**: You **MUST** disclose the use of AI tools when the significant part of the contribution is taken from a tool without changes. You **SHOULD** disclose the other uses of AI tools, where it might be useful. Routine use of assistive tools for correcting grammar and spelling, or for clarifying language, does not require disclosure.

  * Information about the use of AI tools will help us evaluate their impact, build new best practices and adjust existing processes.
  * Disclosures are made where authorship is normally indicated. For contributions tracked in git, the recommended method is an `Assisted-by:` mention either in the commit message trailer, or in the pull request description.
  * Examples:
    * `Assisted-by: generic LLM chatbot`
    * `Assisted-by: ChatGPTv5`

4. **Contribution & Community Evaluation**: AI tools may be used to assist human reviewers by providing analysis and suggestions. You **MUST NOT** use AI as the sole or final arbiter in making a substantive or subjective judgment on a contribution. This does not prohibit the use of automated tooling for objective technical validation, such as CI/CD pipelines, automated testing, or spam filtering. The final accountability for accepting a contribution, even if implemented by an automated system, always rests with the human contributor who authorizes the action.

The key words “MAY”, “MUST”, “MUST NOT”, and “SHOULD” in this document are to be interpreted as described in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).

_Source: This policy was originally based the [Fedora Project policy](https://docs.fedoraproject.org/en-US/council/policy/ai-contribution-policy/)._
