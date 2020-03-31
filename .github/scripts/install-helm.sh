#!/bin/bash -e

# ================================================================================
# Update helm repository that published by GitHub Page
# 
# <Environments>
# 
#   HELM_VERSION ... Helm version which will be installed. (default: "0.7.0")
# ================================================================================
set -o pipefail

HELM_VERSION="${HELM_VERSION:-3.1.0}"

INSTALL_DIR="/usr/local/bin"
if [ -f "${INSTALL_DIR}/helm" ]; then
  echo "[DEBUG] helm is already installed."
  helm version
fi

# ref. https://helm.sh/docs/intro/install/#from-the-binary-releases
pushd $(mktemp -d)
curl -sSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar xz
sudo mv linux-amd64/helm "${INSTALL_DIR}"/helm
rm -rf linux-amd64
popd

helm version
