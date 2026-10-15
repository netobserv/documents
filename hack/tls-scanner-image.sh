#!/usr/bin/env bash

# Build and push the pinned OpenShift TLS scanner image used by tls-scan.sh.
set -euo pipefail

scanner_ref=${TLS_SCANNER_REF:-2e9b3c377b31810bcfe0711a2eb492314e2464be}
scanner_image=${TLS_SCANNER_IMAGE:?Set TLS_SCANNER_IMAGE to a registry image, for example quay.io/my-namespace/tls-scanner:dev}
scanner_platform=${TLS_SCANNER_PLATFORM:-linux/amd64}
oci_bin=${OCI_BIN:-podman}
source_dir=${TLS_SCANNER_SOURCE:-${TMPDIR:-/tmp}/netobserv-tls-scanner-source}

command -v "$oci_bin" >/dev/null || { echo "Missing container tool: $oci_bin" >&2; exit 1; }
command -v git >/dev/null || { echo "Missing command: git" >&2; exit 1; }

if [[ -z ${TLS_SCANNER_SOURCE:-} ]]; then
    if [[ ! -e $source_dir ]]; then
        mkdir -p "$(dirname "$source_dir")"
        git clone https://github.com/openshift/tls-scanner.git "$source_dir"
    fi
    source_root=$(git -C "$source_dir" rev-parse --show-toplevel)
    [[ $(cd "$source_root" && pwd -P) == $(cd "$source_dir" && pwd -P) ]] || {
        echo "$source_dir is not a standalone Git checkout" >&2
        exit 1
    }
    [[ -z $(git -C "$source_dir" status --porcelain) ]] || {
        echo "$source_dir has local changes; use TLS_SCANNER_SOURCE to build it explicitly" >&2
        exit 1
    }
    if ! git -C "$source_dir" cat-file -e "$scanner_ref^{commit}" 2>/dev/null; then
        git -C "$source_dir" fetch https://github.com/openshift/tls-scanner.git "$scanner_ref"
    fi
    git -C "$source_dir" checkout --detach "$scanner_ref"
elif [[ ! -f $source_dir/go.mod || ! -d $source_dir/cmd/tls-scanner ]]; then
    echo "$source_dir is not a tls-scanner source directory" >&2
    exit 1
fi

[[ -f $source_dir/Dockerfile.local ]] || {
    echo "$source_dir/Dockerfile.local is missing; select a source revision that provides it" >&2
    exit 1
}

"$oci_bin" build --platform "$scanner_platform" -f "$source_dir/Dockerfile.local" -t "$scanner_image" "$source_dir"
"$oci_bin" push "$scanner_image"
