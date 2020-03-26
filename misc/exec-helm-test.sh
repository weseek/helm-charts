#!/bin/bash -e

# ================================================================================
# Install helm into tempolary k8s cluster and execute helm test
# 
# <Prerequired>
# 
#   `kubectl`, `helm` command
# ================================================================================

show_help_with_exit() {
cat << EOF
Usage: $(basename "$0") [OPTION]...
Install helm into tempolary k8s cluster and execute helm test.

Mandatory arguments to long options are mandatory for short options too.
  -h, --help               Display help
      --debug              Display verbose output
  -c, --chart=DIRPATH      Base path where charts are (default: "charts")
      --kindver=VERSION    "kind" version (default: "0.7.0")
  -t, --timeout=SECONDS    Timeout of "helm install" command (default: "600")
  -f, --config=CONFPATH    Config file path
EOF

  exit 1
}

main() {
  # --------------------------------------------------------------------------------
  # Get parameters
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
          config="--config $2"
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

  # --------------------------------------------------------------------------------
  # Create k8s cluster using `kind` to test installation ability
  # --------------------------------------------------------------------------------

  pushd $(mktemp -d)

  # Install `kind`
  curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v${kindver}/kind-$(uname)-amd64
  chmod +x kind
  ./kind create cluster ${config}

  # Initialize helm with tiller
  kubectl create serviceaccount --namespace kube-system tiller
  kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
  helm init --wait --service-account tiller
  kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
  helm version --server

  popd

  # --------------------------------------------------------------------------------
  # Install helm and run chart's test
  # --------------------------------------------------------------------------------

  pushd "${chartdir}"

  [ -n "$debug" ] && DEBUG_OPT="--debug" || DEBUG_OPT=""
  for CHART in $(ls -d *); do
    helm install --timeout ${timeout} ${DEBUG_OPT} --dep-up --wait -n ${CHART} ${CHART}
    helm test ${DEBUG_OPT} ${CHART}
    helm delete ${DEBUG_OPT} --purge ${CHART}
  done

  popd
}

main "$@"
