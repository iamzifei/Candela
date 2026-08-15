#!/bin/bash
set -euo pipefail

# Waits until GitHub Pages is serving the files that were built here.
#
# Third attempt, and the first two are worth recording because both failed in ways
# that produced wrong conclusions rather than error messages:
#
#   * Polling a URL until some string appears passes instantly when the string is
#     already there. Waiting on the stylesheet hash after a change that touched only
#     HTML let a screenshot be taken of the previous deploy, and two CSS rules were
#     then diagnosed as "not applying" when they were simply not there yet.
#   * Waiting on the deployment record — either the `pages build and deployment` run
#     for the commit, or the newest github-pages deployment — times out on a deploy
#     that has already succeeded. GitHub coalesces consecutive pushes, so a commit
#     whose content is live may have no run of its own and may never appear as the
#     deployed SHA. Verified: the live stylesheet was byte-identical to the local one
#     while the API still reported the previous commit.
#
# So it compares bytes. A file either matches what was built here or it does not;
# that cannot be true early and cannot be false late.
#
# Usage: ./scripts/wait-for-deploy.sh [timeout-seconds]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="https://zifei.info/Candela"
TIMEOUT="${1:-300}"
START=$(date +%s)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# One file: a fingerprint of the whole published tree, written by site/build.py.
# Naming individual files was the previous version's mistake — it compared the
# stylesheet and the two home pages, so a commit that only DELETED pages left all
# three identical and the wait passed while the removed pages were still served.
check_one() {  # <url> <local path>
  curl -fsS -o "$TMP/live" "$1" 2>/dev/null || return 1
  cmp -s "$TMP/live" "$ROOT/docs/$2"
}

printf '==> Waiting for %s to serve this build' "$SITE"
while true; do
  if check_one "$SITE/build-id.txt" "build-id.txt"; then
    echo " — live"
    exit 0
  fi
  if [ $(( $(date +%s) - START )) -ge "$TIMEOUT" ]; then
    echo
    echo "error: timed out after ${TIMEOUT}s; the site is still serving older files." >&2
    exit 1
  fi
  printf '.'
  sleep 5
done
