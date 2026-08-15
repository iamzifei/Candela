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
# The commit SHA cannot have that failure mode. What it asks is the "pages build and
# deployment" workflow run for this commit — NOT `repos/*/pages/builds/latest`, which
# is the legacy branch-build API and keeps reporting the previous commit on a repo
# whose Pages deploys through Actions. Checked: that endpoint still said 5d73823 long
# after the workflow for 643fcaa had succeeded.
#
# Usage: ./scripts/wait-for-deploy.sh [timeout-seconds]

REPO="$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
WANT="$(git rev-parse HEAD)"
TIMEOUT="${1:-300}"
START=$(date +%s)

printf '==> Waiting for %s to serve %s' "$REPO" "${WANT:0:7}"
while true; do
  # Filtered by run name in jq rather than with --workflow: the Pages deployment is a
  # dynamic workflow with no file in the repo, and `--workflow "pages build and
  # deployment"` answers "could not find any workflows named ...".
  STATE="$(gh run list --repo "$REPO" --commit "$WANT" --limit 20 \
      --json name,status,conclusion \
      --jq '[.[] | select(.name == "pages build and deployment")][0]
            | if . == null then "" else "\(.status) \(.conclusion // "")" end' 2>/dev/null || echo "")"
  case "$STATE" in
    "completed success")
      echo " — deployed"
      exit 0 ;;
    "completed "*)
      echo
      echo "error: Pages deployment for ${WANT:0:7} finished as ${STATE#completed }." >&2
      exit 1 ;;
  esac
  if [ $(( $(date +%s) - START )) -ge "$TIMEOUT" ]; then
    echo
    echo "error: timed out after ${TIMEOUT}s; deployment for ${WANT:0:7} is \"${STATE:-not started}\"." >&2
    exit 1
  fi
  printf '.'
  sleep 5
done
