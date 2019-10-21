#!/usr/bin/env bash

RELEASE_VERSION="$(cat RELEASE_VERSION)"

git commit -a -m "Inject scripts v${RELEASE_VERSION}"
git push -f -u ${GIT_URL} `git rev-parse HEAD`:refs/heads/${CI_COMMIT_REF_NAME}
git push -f -u ${GIT_URL} `git rev-parse HEAD`:refs/heads/release-${RELEASE_VERSION}
git push -f -u ${GIT_URL} `git rev-parse HEAD`:refs/heads/current
