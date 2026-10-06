#!/usr/bin/env bash
# Research-repo gate: shell scripts parse, and nothing secret-shaped is committed (this repo is public until the beta).
set -euo pipefail
cd "$(dirname "$0")/.."
for f in donors/fetch.sh scripts/check.sh; do bash -n "$f"; done
if git ls-files -z -- . ":!scripts/check.sh" | xargs -0 grep -nIE '(ghp_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|service_role|eyJhbGciOi[A-Za-z0-9_-]{20,})' -- ; then
  echo "secret-shaped text found" >&2; exit 1; fi
echo "research gate ok"
