#!/bin/sh

# This should only be run only via jenkins

VERSION="$(cat VERSION)"
PKG_NAME="sigsci-cloudfoundry-buildpack"

KEYBASE="${PKG_NAME}/${GITHUB_RUN_NUMBER}"
TARBALL=sigsci-cloudfoundry-buildpack_${VERSION}.tgz

# Use a different name for the readme to avoid overwriting any README.md in the
# client's buildpack, include the version in the README
echo "Version: ${VERSION}" > README-SIGSCI.md
cat README.md >> README-SIGSCI.md

# create tarball
tar -zcvf $TARBALL README-SIGSCI.md bin/ lib/