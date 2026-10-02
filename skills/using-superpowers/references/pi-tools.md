# Pi Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). On Pi these resolve to the tools and routing skills below.

| Action skills request | Pi equivalent |
| --- | --- |
| Dispatch a subagent (`Agent`, `Task`, or `Subagent` template) | Follow installed delegation routing skills first; otherwise use an available subagent tool |
| Task tracking ("create a todo", "mark complete") | Use the `bd` (beads) CLI via `bash` — Do NOT use TodoWrite |

## Skills and Tools

Pi has native skills but does not expose Claude Code's `Skill` tool. Load the relevant `SKILL.md` with `read` when a skill applies, or let a human invoke `/skill:name` explicitly.

Pi's built-in coding tools are lowercase: `read`, `write`, `edit`, `bash`, plus optional `grep`, `find`, and `ls`. Use those for the corresponding file, shell, and search actions.

## Subagents

Pi core does not ship a standard subagent tool. Its absence from the tool list is not proof that delegation is unavailable.

Before choosing a delegation mechanism, read installed routing skills such as `subagents` and `agent-to-agent`, when present, and follow their instructions. They may launch agents through shell commands or an external coordinator rather than a native tool. Preserve the requested role, brief, scope, and report contract; respect routing restrictions on tools and model selection.

If no routing skill is installed, use an available subagent tool such as `subagent` from `pi-subagents`. Never fabricate `Agent` / `Task` calls. Fall back to inline work only after checking the available routing path and finding it unavailable; report the specific missing prerequisite or capability rather than merely saying that Pi has no native subagent tool.

## Task Tracking and Questions

This plugin tracks ALL tasks with the `bd` (beads) CLI via `bash` — Do NOT use TodoWrite. Use `bd create`, `bd update`, and `bd close`. Only the coordinator manages beads; dispatched agents do not. Run `bd prime` at the start of each session when context is missing.

Pi has no built-in structured question tool unless an extension provides one. Present numbered plain-text options and stop for the user's reply when approval is required.
