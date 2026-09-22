#!/usr/bin/env bash
# tests/skills/test-fork-workflow-invariants.sh — run: bash tests/skills/test-fork-workflow-invariants.sh
# Fail-closed floor for the git-fork apply model (superpowers-omu.1 / superpowers-ev2).
# The v6.4.1 overlay went green on `just check` while dropping stress-test gates
# and bd from The Process. Each live-tree pin has a mutation that MUST go RED.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BRAIN="$ROOT/skills/brainstorming/SKILL.md"
PLANS="$ROOT/skills/writing-plans/SKILL.md"
fail=0

pass() { echo "PASS: $*"; }
bad()  { echo "FAIL: $*"; fail=1; }

extract_section() {
  awk -v want="$1" '
    $0 ~ "^" want "[[:space:]]*$" { insec=1; print; next }
    insec && /^## / { exit }
    insec { print }
  ' "$2"
}

spec_review_block() {
  awk '
    /"header": "Spec review"/ { inh=1 }
    inh { print }
    inh && /"multiSelect"/ { exit }
  ' "$1"
}

has_spec_review_gate() {
  local block
  block=$(spec_review_block "$1")
  printf '%s' "$block" | grep -qF 'Approved + stress-test' || return 1
  printf '%s' "$block" | grep -qF '"label": "Approved",' || return 1
  printf '%s' "$block" | grep -qF '"label": "Needs changes"' || return 1
  return 0
}

has_process_flow_diamond() {
  extract_section '## Process Flow' "$1" | grep -qF '"Stress-test selected\nat gate?" [shape=diamond];'
}

has_bd_label_in_the_process() {
  extract_section '## The Process' "$1" | grep -qF 'bd list --label'
}

has_knowledge_check() {
  extract_section '## Knowledge Check' "$1" | grep -qF 'bd list --label'
}

has_bd_list_parent() {
  grep -qF 'bd list --parent' "$1"
}

index_exports_opencode_plugin() {
  grep -qE 'from ["'"'"']\./\.opencode/plugins/beads-superpowers\.js["'"'"']' "$1"
}

writing_skills_absent() {
  [ ! -e "$1/skills/writing-skills" ]
}

# --- live tree (must be GREEN) ---
if [ ! -f "$BRAIN" ]; then bad "missing $BRAIN"; else
  has_spec_review_gate "$BRAIN" \
    && pass "spec-review gate has Approved / Approved + stress-test / Needs changes" \
    || bad "spec-review gate missing Approved / Approved + stress-test / Needs changes"
  has_process_flow_diamond "$BRAIN" \
    && pass "process-flow diamond includes Stress-test selected" \
    || bad "process-flow diamond missing Stress-test selected"
  has_bd_label_in_the_process "$BRAIN" \
    && pass "bd list --label lives inside brainstorming ## The Process" \
    || bad "bd list --label missing from brainstorming ## The Process"
fi

if [ ! -f "$PLANS" ]; then bad "missing $PLANS"; else
  has_knowledge_check "$PLANS" \
    && pass "writing-plans ## Knowledge Check queries bd list --label" \
    || bad "writing-plans ## Knowledge Check missing bd list --label"
  has_bd_list_parent "$PLANS" \
    && pass "writing-plans has bd list --parent" \
    || bad "writing-plans missing bd list --parent"
fi

if writing_skills_absent "$ROOT"; then
  pass "skills/writing-skills/ is absent"
else
  bad "skills/writing-skills/ must stay absent (drop-list)"
fi

if [ ! -f "$ROOT/index.js" ]; then
  bad "missing index.js"
elif index_exports_opencode_plugin "$ROOT/index.js"; then
  pass "index.js exports .opencode/plugins/beads-superpowers.js"
else
  bad "index.js does not export .opencode/plugins/beads-superpowers.js"
fi

if bash "$ROOT/scripts/check-agents-symlink.sh" >/dev/null; then
  pass "AGENTS.md is a symlink to CLAUDE.md"
else
  bad "AGENTS.md is not a git symlink to CLAUDE.md"
fi

# --- mutations (must be RED) — prove the pins catch the overlay failure mode ---
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Gate JSON dropped (phrase may still appear in Integration).
awk '
  /"header": "Spec review"/ { skip=1 }
  skip && /"multiSelect"/ { skip=0; next }
  skip { next }
  { print }
' "$BRAIN" > "$TMP/brain.md"
if has_spec_review_gate "$TMP/brain.md"; then
  bad "mutation: stripped Spec review JSON still passed the gate check"
else
  pass "mutation: stripped Spec review JSON is RED"
fi

# Diamond relabeled so stress-test is no longer a gate node.
sed 's/Stress-test selected/Something else selected/g' "$BRAIN" > "$TMP/flow.md"
if has_process_flow_diamond "$TMP/flow.md"; then
  bad "mutation: missing Stress-test diamond still passed"
else
  pass "mutation: missing Stress-test diamond is RED"
fi

# bd list --label moved out of The Process into a trailing appendix (the overlay shape).
awk '
  $0 == "## The Process" { insec=1 }
  insec && /^## / && $0 != "## The Process" { insec=0 }
  insec && /bd list --label/ { next }
  { print }
  END { print "\n## Appendix\n- `bd list --label <topic> --status all`\n" }
' "$BRAIN" > "$TMP/process.md"
if has_bd_label_in_the_process "$TMP/process.md"; then
  bad "mutation: appendix-only bd list --label still passed The Process check"
else
  pass "mutation: appendix-only bd list --label is RED"
fi

# Knowledge Check heading renamed so the query is no longer in that section.
sed 's/^## Knowledge Check$/## Something Else/' "$PLANS" > "$TMP/plans.md"
if has_knowledge_check "$TMP/plans.md"; then
  bad "mutation: missing Knowledge Check still passed"
else
  pass "mutation: missing Knowledge Check is RED"
fi

grep -vF 'bd list --parent' "$PLANS" > "$TMP/plans-parent.md"
if has_bd_list_parent "$TMP/plans-parent.md"; then
  bad "mutation: missing bd list --parent still passed"
else
  pass "mutation: missing bd list --parent is RED"
fi

mkdir -p "$TMP/tree/skills/writing-skills"
if writing_skills_absent "$TMP/tree"; then
  bad "mutation: resurrected writing-skills still passed"
else
  pass "mutation: resurrected writing-skills is RED"
fi

echo 'export default 1;' > "$TMP/index.js"
if index_exports_opencode_plugin "$TMP/index.js"; then
  bad "mutation: index.js without the OpenCode export still passed"
else
  pass "mutation: index.js without the OpenCode export is RED"
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: fork-workflow invariants"
  exit 0
fi
exit 1
