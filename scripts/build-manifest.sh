#!/usr/bin/env bash
# Print the identity of a build: base revision, toolchain, and the sha256 of
# every patch in patches/ (in order).  save-build.sh stores it in the pack as
# MANIFEST; setup-env.sh compares it to decide whether a pack is current.
# With --tag, print instead the GitHub release tag for that identity:
# build-<first 12 hex digits of the MANIFEST's sha256>.
set -euo pipefail
PROJECT=$(cd "$(dirname "$0")/.." && pwd)
manifest() {
  echo "ooRexx SVN trunk r${OOREXX_REV:-13263}"
  echo "Emscripten ${EMVER:-6.0.9}"
  for p in "$PROJECT"/patches/*.patch; do
    echo "patch $(basename "$p") $(sha256sum "$p" | cut -c1-64)"
  done
}
if [[ "${1:-}" == "--tag" ]]; then echo "build-$(manifest | sha256sum | cut -c1-12)"; else manifest; fi
