#!/bin/bash -e

# ================================================================================
# Create k8s cluster using `kind`
# 
# <Environment>
# 
#   SRC_CHART_PATH_BASE ... base path where charts are (default: "charts")
#   KIND_VERSION        ... `kind` version (default: "0.7.0")
#   TIMEOUT             ... timeout of `helm install` command (default: "600")
# 
# <Prerequired>
# 
#   `kubectl`, `helm` command
# ================================================================================

# --------------------------------------------------------------------------------
# Create k8s cluster using `kind` to test installation ability
# --------------------------------------------------------------------------------

SRC_CHART_PATH_BASE=${SRC_CHART_PATH_BASE:-charts}
KIND_VERSION=${KIND_VERSION:-0.7.0}
TIMEOUT=${TIMEOUT:-600}

SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
KIND_CONFIG_PATH="${SCRIPT_DIR}/kind-config.yaml"
if [ ! -f "$KIND_CONFIG_PATH" ]; then
  echo "exec-helm-test.sh error: cannot found config. $KIND_CONFIG_PATH" >&2
  exit 1
fi

pushd $(mktemp -d)

# Install `kind`
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-$(uname)-amd64
chmod +x kind
./kind create cluster --config "${KIND_CONFIG_PATH}"

# Initialize helm with tiller
kubectl create serviceaccount --namespace kube-system tiller \
  && kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller \
  && helm init --wait --service-account tiller \
  && kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm version --server

popd

# --------------------------------------------------------------------------------
# Install helm and run chart's test
# --------------------------------------------------------------------------------

pushd "${SRC_CHART_PATH_BASE}"

for CHART in $(ls -d *); do
  (helm install --timeout ${TIMEOUT} --debug --dep-up --wait -n ${CHART} ${CHART} \
    && helm test --debug ${CHART} \
    && helm delete --purge ${CHART}) \
    || exit 1
done

popd
