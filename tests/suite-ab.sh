#!/bin/bash
# A/B run of the official suite with two native builds, one after the other
# (never concurrently: the groups share their directory's temp files, rxapi
# and socket ports).  Resumable: run it again after an interruption.
#   suite-ab.sh REXX_A OUT_A REXX_B OUT_B [JOBS=2]
set -u
D=$(dirname "$0")
"$D/run-suite.sh" "$1" "$2" "${5:-2}" 300 && "$D/run-suite.sh" "$3" "$4" "${5:-2}" 300 && echo AB-DONE > "$4/AB-DONE"
