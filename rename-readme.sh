#!/bin/sh

# rename README.md to avoid potential conflicts with customer's README.md file
echo "Version: ${VERSION}" > README.md
mv README.md README-SIGSCI.md

