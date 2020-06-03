#!/bin/bash

test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

project="cilium-ci"
# this is only needs to be set as some of gcloud commands requires it,
# but as this script uses resource URIs clusters in all locations are
# going to be discovered and used
region="us-west1"

export KUBECONFIG="${script_dir}/gke-kubeconfig"
cluster_uri="$(cat "${script_dir}/cluster-uri")"

# Create a function to unlock the cluster. We then execute this on script exit.
# This should occur even if the script is interrupted, by a jenkins timeout,
# for example.
unlock() {    
    echo "releasing cluster lock from ${cluster_uri}"
    kubectl annotate deployment lock lock-
}
trap unlock EXIT

# We leak istio pods for an unknown reason (these tests do cleanup). This may
# be related to timeouts or other failures. In any case, we delete them here to
# be sure.
echo "deleting istio-system namespace and contents"
kubectl delete all -n istio-system --all
kubectl delete ns istio-system

echo "deleting terminating namespaces"
./delete-terminating-namespaces.sh

set -e

echo "scaling ${cluster_uri} to 0"
${script_dir}/resize-cluster.sh 0 ${cluster_uri}

rm -f "${script_dir}/cluster-uri" "${script_dir}/cluster-name" "${script_dir}/cluster-version"
