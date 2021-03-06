#!/bin/bash -e

# ================================================================================
# Create kind cluster and execute "helm test"
# 
# <What you need to execute>
# 
#   `kubectl`, `helm` command
# ================================================================================

show_help_with_exit() {
cat << EOF
Usage: $(basename "$0") [OPTION]...
Create kind cluster and execute "helm test".

Mandatory arguments to long options are mandatory for short options too.
  -h, --help                Display help
      --debug               Display verbose output
  -c, --chartdir=DIRPATH    Base path where charts are (default: "charts")
      --kindver=VERSION     "kind" version (default: "0.7.0")
  -t, --timeout=SECONDS     Timeout of "helm install" command (default: "600")
  -f, --config=CONFPATH     Config file path
EOF

  exit 1
}

main() {
  # --------------------------------------------------------------------------------
  # Get parameters
  # (ref. https://github.com/helm/chart-releaser-action/blob/5ecd0f7f1ac8eb35a24baa68eaf39ed0f08325ac/cr.sh)
  # --------------------------------------------------------------------------------

  local debug=
  local chartdir=charts
  local kindver=0.7.0
  local timeout=600
  local config=

  while :; do
    case "${1:-}" in
      -h|--help)
        show_help_with_exit
        ;;
      --debug)
        debug=true
        ;;
      -c|--chartdir)
        if [[ -n "${2:-}" ]]; then
          chartdir="$2"
          shift
        else
          echo "ERROR: '--chart' cannot be empty." >&2
          show_help_with_exit
        fi
        ;;
      --kindver)
        if [[ -n "${2:-}" ]]; then
          kindver="$2"
          shift
        else
          echo "ERROR: '--kindver' cannot be empty." >&2
          show_help_with_exit
        fi
        ;;
      -t|--timeout)
        if [[ -n "${2:-}" ]]; then
          timeout="$2"
          shift
        else
          echo "ERROR: '--timeout' cannot be empty." >&2
          show_help_with_exit
        fi
        ;;
      -f|--config)
        if [[ -n "${2:-}" ]]; then
          config="$2"
          shift
        else
          echo "ERROR: '--config' cannot be empty." >&2
          show_help_with_exit
        fi
        ;;
      *)
        break
        ;;
    esac
    
    shift
  done

  [ -n "$config" ] && KIND_CONFIG_OPT="--config ${config}" || KIND_CONFIG_OPT=""
  [ -n "$debug" ]  && KIND_VERBOSE_OPT="-v 10"             || KIND_VERBOSE_OPT=""
  [ -n "$debug" ]  && KUBECTL_VERBOSE_OPT="-v 10"          || KUBECTL_VERBOSE_OPT=""
  [ -n "$debug" ]  && HELM_DEBUG_OPT="--debug"             || HELM_DEBUG_OPT=""

  # --------------------------------------------------------------------------------
  # Create kind cluster and execute "helm test"
  # --------------------------------------------------------------------------------

  # Install `kind` if it doesn't exist
  KIND=$(which kind) || true
  if [ -z "${KIND}" ]; then
    echo "Installing kind..."

    TMP_KIND_DIR=$(mktemp -d)
    trap "rm -rfv ${TMP_KIND_DIR}" EXIT

    pushd ${TMP_KIND_DIR}
    curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v${kindver}/kind-$(uname)-amd64
    chmod +x kind
    popd

    KIND="${TMP_KIND_DIR}/kind"
  fi

  CLUSTER_NAME="exec-helm-test-$RANDOM"
  ${KIND} create cluster --name ${CLUSTER_NAME} ${KIND_VERBOSE_OPT} ${KIND_CONFIG_OPT}

  # Initialize helm with tiller
  kubectl create serviceaccount --namespace kube-system tiller ${KUBECTL_VERBOSE_OPT}
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller ${KUBECTL_VERBOSE_OPT}
  helm init --wait --service-account tiller ${HELM_DEBUG_OPT}
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' ${KUBECTL_VERBOSE_OPT}
  helm version --server ${HELM_DEBUG_OPT}

  # --------------------------------------------------------------------------------
  # Install helm and run chart's test
  # --------------------------------------------------------------------------------

  pushd "${chartdir}"

  for CHART in $(ls -d *); do
    helm install --dep-up --wait --timeout ${timeout} -n ${CHART} ${HELM_DEBUG_OPT} ${CHART}
    helm test ${HELM_DEBUG_OPT} ${CHART}
    helm delete --purge ${HELM_DEBUG_OPT} ${CHART}
  done

  popd

  ${KIND} delete cluster --name ${CLUSTER_NAME}
}

main "$@"
