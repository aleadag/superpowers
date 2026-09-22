---
name: merging-upstream-superpowers
description: Use when merging an obra/superpowers tag into this fork (branch beads), after a Superpowers release, or when applying vX.Y.Z here. Maintainer-only — not distributed.
---

# Merging Upstream Superpowers

> **Maintainer-only — not distributed.** Same class as `auditing-upstream-drift`. Not in `install.sh` `KNOWN_SKILLS`. Merge engine is Git (`superpowers-ev2`).

Before anything else: if this is not the beads-superpowers product tree (`aleadag/superpowers`, branch `beads`, plugin name `beads-superpowers`), say so and STOP.

`auditing-upstream-drift` answers "are we stale?". This playbook applies a tag. Do not grow the audit into an apply engine.

## Read first

The knowledge-beads are the SSOT. Show them before merging; do not restate their keep/drop lists or command tables here.

```bash
bd show superpowers-cm3 superpowers-8j5 superpowers-31y superpowers-ev2
```

| Bead | What it owns |
|------|----------------|
| `superpowers-cm3` | Git-fork apply model, remotes, fork point, history |
| `superpowers-8j5` | Live path (not appendix); keep / drop / copy-class |
| `superpowers-31y` | `bsp-<tag>` version bump |
| `superpowers-ev2` | No shipped merge skill |

## Apply

On `beads`:

1. `git fetch superpowers --tags`
2. `git merge vX.Y.Z`
3. Resolve like a normal fork. Judgment from `superpowers-8j5`. Overlay JSON, `generating-from-upstream`, and `git merge-file` as the apply engine stay dead (`superpowers-cm3`). Intent notes inform judgment only.
4. `./scripts/bump-version.sh bsp-X.Y.Z` and hand-bump Hermes `plugin.yaml` (`superpowers-31y`). Changelog: add `[bsp-X.Y.Z]`; keep `0.16.0` as history.
5. Floor: `just check` **and** `bash tests/skills/test-fork-workflow-invariants.sh`. Unrelated guards green with beads only in an appendix is a failed merge (`superpowers-8j5`).
6. Do not add a merge helper under `skills/` or `KNOWN_SKILLS` (`superpowers-ev2`).

## Hard stops

- Do not resurrect `generating-from-upstream` or overlay JSON as the apply engine
- Do not ship a merge helper in `skills/`
- `skills/writing-skills/` stays deleted
- `index.js` exports `.opencode/plugins/beads-superpowers.js`
- `AGENTS.md` stays a symlink to `CLAUDE.md`

## After

Run `auditing-upstream-drift` for staleness / release. It is not the merge.
