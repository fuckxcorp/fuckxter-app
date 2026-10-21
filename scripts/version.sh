#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
line=$(sed -n 's/^version: *//p' pubspec.yaml | tr -d '\r')
if [[ ! "$line" =~ ^([0-9]+\.[0-9]\.[0-9])\+([1-9][0-9]*)$ ]]; then
  echo 'pubspec.yaml must contain version: major.minor.patch+build (minor and patch: 0–9)' >&2
  exit 1
fi
export APP_VERSION="${BASH_REMATCH[1]}"
export APP_BUILD="${BASH_REMATCH[2]}"
