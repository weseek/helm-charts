#!/bin/bash -e

# ================================================================================
# Update helm repository that published by GitHub Page
# 
# <Environments>
# 
#   SRC_CHART_PATH_BASE ... base path where charts are (default: "charts")
#   GH_PAGES_BRANCH     ... branch name for GitHub Page. (default: "gh-pages")
# ================================================================================

SRC_CHART_PATH_BASE=${SRC_CHART_PATH_BASE:-charts}
GH_PAGES_BRANCH=${GH_PAGES_BRANCH:-gh-pages}

# Initialize working directory
GH_PAGES_WORKTREE="$(mktemp -d)"
git fetch --no-tags --prune --depth=1 origin +refs/heads/*:refs/remotes/origin/*
git worktree add "${GH_PAGES_WORKTREE}" ${GH_PAGES_BRANCH}

# Create helm packages
helm init --client-only
helm package "${SRC_CHART_PATH_BASE}"/* --destination "${GH_PAGES_WORKTREE}" --dependency-update --save=false

# Update helm repo index
pushd "${GH_PAGES_WORKTREE}"
helm repo index .
git add .
git diff # debug info
git commit -m "Update helm packages"
git push origin ${GH_PAGES_BRANCH}
popd
git worktree remove "${GH_PAGES_WORKTREE}"