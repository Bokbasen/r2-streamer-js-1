#!/bin/bash

function build_app() {
  pushd .
  npm run build:lambda
  local status=$?
  if [[ ${status} -ne 0 ]]; then
    echo "Failed to build app: $status"
    exit $status
  fi
}

###
# Build node project
build_app
