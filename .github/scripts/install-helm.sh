#!/bin/bash -e

# ================================================================================
# Update helm repository that published by GitHub Page
# 
# <Environments>
# 
#   HELM_VERSION ... Helm version which will be installed. (default: "3.5.4")
# ================================================================================
set -o pipefail

HELM_VERSION="${HELM_VERSION:-3.5.4}"

INSTALL_DIR="/usr/local/bin"
if [ -f "${INSTALL_DIR}/helm" ]; then
  echo "[DEBUG] helm is already installed."
  helm version --client
fi

# ref. https://helm.sh/docs/intro/install/#from-the-binary-releases
pushd $(mktemp -d)
curl -sSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm "${INSTALL_DIR}"/helm
rm -rf linux-amd64
popd

helm version --client
