#!/usr/bin/env bash

RELEASE_VERSION="$(cat RELEASE_VERSION)"

git commit -a -m "Inject scripts v${RELEASE_VERSION}"
git push -f -u ${GIT_URL} `git rev-parse HEAD`:refs/heads/${CI_COMMIT_REF_NAME}
git tag -a v${RELEASE_VERSION} -m "v${RELEASE_VERSION}"
git push -u ${GIT_URL} --tags
git push -f -u ${GIT_URL} `git rev-parse HEAD`:refs/heads/release-${RELEASE_VERSION}
git push -f -u ${GIT_URL} `git rev-parse HEAD`:refs/heads/current
