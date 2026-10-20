#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_SOURCE="$REPO_ROOT/scripts/bump-version.sh"
TEST_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_fixture() {
  local repo="$1"
  local yaml_body="$2"

  mkdir -p "$repo/scripts" "$repo/.hermes-plugin"
  cp "$SCRIPT_SOURCE" "$repo/scripts/bump-version.sh"
  cat >"$repo/.version-bump.json" <<'JSON'
{
  "files": [
    { "path": "package.json", "key": "version" }
  ],
  "audit": { "exclude": [".hermes-plugin"] }
}
JSON
  cat >"$repo/package.json" <<'JSON'
{
  "name": "fixture",
  "version": "1.2.3"
}
JSON
  printf '%s\n' "$yaml_body" >"$repo/.hermes-plugin/plugin.yaml"
}

# YAML support is optional here: the fork hand-bumps Hermes without yq.
if command -v yq >/dev/null 2>&1; then
happy_repo="$TEST_ROOT/happy"
make_fixture "$happy_repo" $'name: superpowers\nversion: 1.2.3'
jq '.files += [{"path": ".hermes-plugin/plugin.yaml", "key": "version"}]' \
  "$happy_repo/.version-bump.json" > "$TEST_ROOT/config.json"
cp -f "$TEST_ROOT/config.json" "$happy_repo/.version-bump.json"

/bin/bash "$happy_repo/scripts/bump-version.sh" --check >"$TEST_ROOT/check.out"
/bin/bash "$happy_repo/scripts/bump-version.sh" --audit >"$TEST_ROOT/audit.out"
/bin/bash "$happy_repo/scripts/bump-version.sh" 2.3.4 >"$TEST_ROOT/bump.out"

[[ "$(jq -r '.version' "$happy_repo/package.json")" == "2.3.4" ]] \
  || fail "JSON manifest was not bumped"
[[ "$(yq -r '.version' "$happy_repo/.hermes-plugin/plugin.yaml")" == "2.3.4" ]] \
  || fail "YAML manifest was not bumped"

invalid_repo="$TEST_ROOT/invalid"
make_fixture "$invalid_repo" $'name: superpowers\nversion: 123'
cp -f "$TEST_ROOT/config.json" "$invalid_repo/.version-bump.json"
cp "$invalid_repo/package.json" "$TEST_ROOT/package.before"
cp "$invalid_repo/.hermes-plugin/plugin.yaml" "$TEST_ROOT/plugin.before"

if /bin/bash "$invalid_repo/scripts/bump-version.sh" 2.3.4 \
  >"$TEST_ROOT/invalid.out" 2>&1; then
  fail "bump accepted a non-string YAML version"
fi

cmp -s "$TEST_ROOT/package.before" "$invalid_repo/package.json" \
  || fail "JSON manifest changed before YAML validation failed"
cmp -s "$TEST_ROOT/plugin.before" "$invalid_repo/.hermes-plugin/plugin.yaml" \
  || fail "invalid YAML manifest changed"

else
  echo "SKIP: yq not on PATH; YAML version-bump tests"
fi

audit_repo="$TEST_ROOT/audit-boundaries"
make_fixture "$audit_repo" $'name: superpowers\nversion: 1.2.3'
/bin/bash "$audit_repo/scripts/bump-version.sh" 4.0.0 >/dev/null
printf 'host = "10.4.0.0"\n' >"$audit_repo/server.js"
printf 'pin: superpowers.git#v4.0.0\n' >"$audit_repo/INSTALL.md"
/bin/bash "$audit_repo/scripts/bump-version.sh" --audit >"$TEST_ROOT/audit-boundaries.out"

grep -q 'INSTALL.md' "$TEST_ROOT/audit-boundaries.out" \
  || fail "audit missed an undeclared #v4.0.0 pin"
if grep -q 'server.js' "$TEST_ROOT/audit-boundaries.out"; then
  fail "audit flagged 10.4.0.0 as version 4.0.0"
fi

echo "Version-bump tests passed"
