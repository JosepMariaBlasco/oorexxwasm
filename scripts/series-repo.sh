#!/usr/bin/env bash
# Work on the patch series as git commits: build a git repository from ooRexx
# trunk r$REV (svn export) with patches/*.patch applied by `git am`
# (one commit per patch), tagged base.  Edit / rebase there, then export the
# series back with scripts/series-export.sh.
# Usage: series-repo.sh [DIR=$ORX_WASM_WORK/series-git]
ORX_WASM_WORK=${ORX_WASM_WORK:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/../.." && pwd)}   # where oorexx/, build-wasm/ ... live
set -euo pipefail
REV=${OOREXX_REV:-13254}
DIR=${1:-$ORX_WASM_WORK/series-git}
PROJECT=$(cd "$(dirname "$0")/.." && pwd)
[[ -e "$DIR" ]] && { echo "$DIR exists" >&2; exit 1; }
svn export -q -r "$REV" https://svn.code.sf.net/p/oorexx/code-0/main/trunk "$DIR"
cd "$DIR"
git init -q
git config user.name "Josep Maria Blasco"; git config user.email josep.maria.blasco@epbcn.com
git add -A && git commit -qm "ooRexx trunk r$REV" && git tag base
git am -q "$PROJECT"/patches/*.patch
git log --oneline
