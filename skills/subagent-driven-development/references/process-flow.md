## The Process

```dot
digraph process {
    rankdir=TB;

    subgraph cluster_per_task {
        label="Per Task";
        "Dispatch fresh implementer (./implementer-prompt.md)" [shape=box];
        "Implementer implements, tests, commits, self-reviews" [shape=box];
        "Generate review package, dispatch task reviewer (./task-reviewer-prompt.md)" [shape=box];
        "Spec and quality approved + full suite green?" [shape=diamond];
        "Record ROUND0_HEAD before first fix" [shape=box];
        "Fix round R of 5: fresh implementer + latest report; R>=4 more capable model" [shape=box];
        "Covering tests + full suite; dispatch scoped re-review (./re-review-prompt.md)" [shape=box];
        "All findings addressed + full suite green?" [shape=diamond];
        "R = 5?" [shape=diamond];
        "File findings at original severity, block task, hold branch unmerged" [shape=box];
        "User decides: resolve findings or discard fix rounds to ROUND0_HEAD" [shape=box];
        "Append verified completion to ledger, bd close" [shape=box];
    }

    "Setup: worktree, ledger check, read plan, pre-flight review" -> "Dispatch fresh implementer (./implementer-prompt.md)";
    "Dispatch fresh implementer (./implementer-prompt.md)" -> "Implementer implements, tests, commits, self-reviews";
    "Implementer implements, tests, commits, self-reviews" -> "Generate review package, dispatch task reviewer (./task-reviewer-prompt.md)";
    "Generate review package, dispatch task reviewer (./task-reviewer-prompt.md)" -> "Spec and quality approved + full suite green?";
    "Spec and quality approved + full suite green?" -> "Append verified completion to ledger, bd close" [label="yes"];
    "Spec and quality approved + full suite green?" -> "Record ROUND0_HEAD before first fix" [label="no"];
    "Record ROUND0_HEAD before first fix" -> "Fix round R of 5: fresh implementer + latest report; R>=4 more capable model";
    "Fix round R of 5: fresh implementer + latest report; R>=4 more capable model" -> "Covering tests + full suite; dispatch scoped re-review (./re-review-prompt.md)";
    "Covering tests + full suite; dispatch scoped re-review (./re-review-prompt.md)" -> "All findings addressed + full suite green?";
    "All findings addressed + full suite green?" -> "Append verified completion to ledger, bd close" [label="yes"];
    "All findings addressed + full suite green?" -> "R = 5?" [label="no"];
    "R = 5?" -> "Fix round R of 5: fresh implementer + latest report; R>=4 more capable model" [label="no - next round"];
    "R = 5?" -> "File findings at original severity, block task, hold branch unmerged" [label="yes - breaker trips"];
    "File findings at original severity, block task, hold branch unmerged" -> "User decides: resolve findings or discard fix rounds to ROUND0_HEAD";
    "Append verified completion to ledger, bd close" -> "More tasks remain?";
    "More tasks remain?" -> "Dispatch fresh implementer (./implementer-prompt.md)" [label="yes"];
    "More tasks remain?" -> "Dispatch final whole-branch reviewer" [label="no"];
    "Dispatch final whole-branch reviewer" -> "Final findings?";
    "Final findings?" -> "ONE fix dispatch, full suite, ONE scoped re-review" [label="yes"];
    "Final findings?" -> "Final review clean + full suite green" [label="no"];
    "ONE fix dispatch, full suite, ONE scoped re-review" -> "Residual findings?";
    "Residual findings?" -> "File findings at original severity, block task, hold branch unmerged" [label="yes"];
    "Residual findings?" -> "Final review clean + full suite green" [label="no"];
    "Final review clean + full suite green" -> "Delete only this plan's workspace";
    "Delete only this plan's workspace" -> "Use beads-superpowers:finishing-a-development-branch";
}
```

At either review cap, follow [breaker-trip.md](breaker-trip.md). Security
findings block the epic and are never parkable. In a parallel batch, passing
siblings may finish normally; the tripped task stays unmerged and its
dependents stay blocked until the user decides its disposition.
