#!/bin/bash -e

# ================================================================================
# Update the helm repository on GitHub Pages
# 
# <Environments>
# 
#   SRC_CHARTS_PATH_BASE ... base path where charts are (default: "charts")
#   GH_PAGES_BRANCH      ... branch name for GitHub Page. (default: "gh-pages")
# ================================================================================

SRC_CHARTS_PATH_BASE=${SRC_CHARTS_PATH_BASE:-charts}
GH_PAGES_BRANCH=${GH_PAGES_BRANCH:-gh-pages}

# Initialize working directory
GH_PAGES_WORKTREE="$(mktemp -d)"
git fetch --no-tags --prune --depth=1 origin +refs/heads/*:refs/remotes/origin/*
git worktree add "${GH_PAGES_WORKTREE}" ${GH_PAGES_BRANCH}

# Create helm packages
helm package "${SRC_CHARTS_PATH_BASE}"/* --destination "${GH_PAGES_WORKTREE}" --dependency-update

# Update helm repo index
# (ref. https://github.com/helm/chart-releaser-action/blob/5ecd0f7f1ac8eb35a24baa68eaf39ed0f08325ac/cr.sh#L212-L234)
pushd "${GH_PAGES_WORKTREE}"
helm repo index .
git add .
git diff # debug info
git commit -m "Update helm packages"
git push origin ${GH_PAGES_BRANCH}
popd
git worktree remove "${GH_PAGES_WORKTREE}"
