#!/bin/bash
set -euo pipefail

# Waits until GitHub Pages is serving the commit that is checked out here.
#
# Written because the obvious way to wait — poll a URL until some string appears —
# quietly does the wrong thing when the string is already there. Waiting on the
# stylesheet's hash after a change that touched only HTML passed instantly, so the
# next screenshot was of the previous deploy. That cost two wrong diagnoses in a row:
# a CSS rule declared "not applying" and a selector declared "not matching", both of
# which were fine in the version that had not arrived yet.
#
# The commit SHA cannot have that failure mode. Pages reports which commit it built,
# so this asks it, rather than guessing from page content.
#
# Usage: ./scripts/wait-for-deploy.sh [timeout-seconds]

REPO="$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
WANT="$(git rev-parse HEAD)"
TIMEOUT="${1:-300}"
START=$(date +%s)

printf '==> Waiting for %s to serve %s' "$REPO" "${WANT:0:7}"
while true; do
  BUILT="$(gh api "repos/$REPO/pages/builds/latest" --jq '.commit + " " + .status' 2>/dev/null || echo "")"
  SHA="${BUILT%% *}"
  STATUS="${BUILT##* }"
  if [ "$SHA" = "$WANT" ] && [ "$STATUS" = "built" ]; then
    echo " — built"
    exit 0
  fi
  if [ "$STATUS" = "errored" ]; then
    echo
    echo "error: Pages build for ${SHA:0:7} errored." >&2
    exit 1
  fi
  if [ $(( $(date +%s) - START )) -ge "$TIMEOUT" ]; then
    echo
    echo "error: timed out after ${TIMEOUT}s; Pages is serving ${SHA:0:7} ($STATUS)." >&2
    exit 1
  fi
  printf '.'
  sleep 5
done
