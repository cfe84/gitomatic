#!/bin/bash

cd $(dirname "$0")
WD=`pwd`

REPO="$1"
REF="$2"

cd "$REPO"
git ls-tree --name-only $REF .build/ | grep '.ini$'