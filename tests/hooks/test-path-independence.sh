#!/usr/bin/env bash
# v7.0.0 regressions: broken PATH must not prevent the bootstrap, including
# when dispatched through the polyglot wrapper. Beads composition still runs
# on a normal PATH (covered by the composer suites).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASH_BIN="$(command -v bash)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home" "$TMP/bin" "$TMP/root"
fail=0

check() {
    local label="$1"; shift
    local rc=0
    env -i HOME="$TMP/home" CLAUDE_PLUGIN_ROOT="$ROOT" "$@" \
        > "$TMP/out" 2> "$TMP/err" < /dev/null || rc=$?
    if [ "$rc" -eq 0 ] && [ ! -s "$TMP/err" ] && python3 - "$TMP/out" <<'PY'
import json
import sys
with open(sys.argv[1]) as f:
    context = json.load(f)["hookSpecificOutput"]["additionalContext"]
assert "Skill Name Resolution" in context
assert "beads-superpowers:using-superpowers" in context
assert "unreadable" not in context
PY
    then
        echo "PASS: $label"
    else
        echo "FAIL: $label (exit $rc)"
        cat "$TMP/err"
        fail=1
    fi
}

check "direct hook with empty PATH" PATH="" "$BASH_BIN" "$ROOT/hooks/session-start"
check "wrapper with empty PATH" PATH="" "$BASH_BIN" "$ROOT/hooks/run-hook.cmd" session-start
check "bare hook filename" PATH="" "$BASH_BIN" -c \
    'cd "$1" && exec "$2" session-start' _ "$ROOT/hooks" "$BASH_BIN"
check "bare wrapper filename" PATH="" "$BASH_BIN" -c \
    'cd "$1" && exec "$2" run-hook.cmd session-start' _ "$ROOT/hooks" "$BASH_BIN"

if command -v cygpath >/dev/null 2>&1; then
    check "backslash hook path" PATH="" "$BASH_BIN" "$(cygpath -w "$ROOT/hooks/session-start")"
else
    ln -s "$ROOT/hooks" "$TMP/root/hooks"
    ln -s "$ROOT/skills" "$TMP/root/skills"
    ln -s "$ROOT/hooks/session-start" "$TMP/root/hooks\\session-start"
    check "backslash hook path" PATH="" "$BASH_BIN" -c \
        'cd "$1" && exec "$2" "$3"' _ "$TMP/root" "$BASH_BIN" 'hooks\session-start'
fi

# A cat-only PATH exercises both the degraded bootstrap and upstream's EPIPE
# workaround without depending on any other external utility.
printf '#!%s\n: > "%s"\nexec "%s" "$@"\n' \
    "$BASH_BIN" "$TMP/cat-used" "$(command -v cat)" > "$TMP/bin/cat"
chmod +x "$TMP/bin/cat"
check "cat-only PATH" PATH="$TMP/bin" "$BASH_BIN" "$ROOT/hooks/session-start"
if [ -f "$TMP/cat-used" ]; then
    echo "PASS: JSON output piped through cat when available"
else
    echo "FAIL: cat not used for JSON output"
    fail=1
fi
exit "$fail"
