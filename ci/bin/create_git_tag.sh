#!/usr/bin/env bash

ROOT_DIR="."
RELEASE_VERSION="$(cat $ROOT_DIR/RELEASE_VERSION)"

set -e -x -o pipefail
# add || true to end of the curl command for debuging that always return success in job
curl -X POST --show-error --fail "https://gitlab.x.apli.tech/api/v4/projects/${CI_PROJECT_ID}/repository/tags?tag_name=v${RELEASE_VERSION}&ref=${CI_COMMIT_SHA}&private_token=${GITLAB_TOKEN}" || true