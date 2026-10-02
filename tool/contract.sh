#!/usr/bin/env bash
# The backend contract this app is built against: a copy of DimaM18/SpoRand's
# packages/protocol/fixtures and packages/protocol/generated/client-registry.json
# at the commit pinned in contract/SOURCE. The tests read only this copy.
#
#   tool/contract.sh sync  <SpoRand checkout>   copy the contract from a clean checkout and pin its commit
#   tool/contract.sh check <SpoRand checkout>   fail if contract/ differs from that checkout or the pin
#
# CI (.github/workflows/e2e.yml) checks out the pinned commit and runs `check`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACT="$ROOT/contract"
SOURCE_FILE="$CONTRACT/SOURCE"
REPOSITORY="DimaM18/SpoRand"

usage() {
  echo "usage: tool/contract.sh sync|check <SpoRand checkout>" >&2
  exit 2
}

[[ $# -eq 2 ]] || usage
command="$1"
backend="$(cd "$2" && pwd)"
protocol="$backend/packages/protocol"
[[ -d "$protocol/fixtures" && -f "$protocol/generated/client-registry.json" ]] || {
  echo "contract: $backend is not a SpoRand checkout (no packages/protocol/fixtures)" >&2
  exit 1
}
commit="$(git -C "$backend" rev-parse HEAD)"

pinned_commit() {
  sed -n 's/^commit=//p' "$SOURCE_FILE"
}

case "$command" in
  sync)
    if [[ -n "$(git -C "$backend" status --porcelain -- packages/protocol)" ]]; then
      echo "contract: packages/protocol has uncommitted changes in $backend; the contract comes from a commit" >&2
      exit 1
    fi
    rm -rf "$CONTRACT/fixtures" "$CONTRACT/generated"
    mkdir -p "$CONTRACT/generated"
    cp -R "$protocol/fixtures" "$CONTRACT/fixtures"
    cp "$protocol/generated/client-registry.json" "$CONTRACT/generated/client-registry.json"
    printf 'repository=%s\ncommit=%s\n' "$REPOSITORY" "$commit" >"$SOURCE_FILE"
    echo "contract: synced from $REPOSITORY@$commit"
    echo "next: flutter test (the drift tests), then commit contract/ with the app changes it needs"
    ;;
  check)
    status=0
    pinned="$(pinned_commit)"
    if [[ "$pinned" != "$commit" ]]; then
      echo "contract: contract/SOURCE pins $pinned, the checkout is at $commit" >&2
      status=1
    fi
    diff -r "$protocol/fixtures" "$CONTRACT/fixtures" >&2 || status=1
    cmp "$protocol/generated/client-registry.json" "$CONTRACT/generated/client-registry.json" >&2 || status=1
    if [[ $status -ne 0 ]]; then
      echo "contract: contract/ is not the backend contract at the pin; run tool/contract.sh sync" >&2
      exit 1
    fi
    echo "contract: OK ($REPOSITORY@$commit)"
    ;;
  *)
    usage
    ;;
esac
