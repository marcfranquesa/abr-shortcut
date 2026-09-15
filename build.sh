#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
osacompile -o 'build/Enable Admin.app' enable-admin.applescript
osacompile -o 'build/Stop Admin.app' stop-admin.applescript
