# Repository agent rules

## GitHub and P0 state

GitHub is authoritative for PR and Actions state. Conversation summaries, memory, and this repository's historical status notes are pointers only; they can be stale. Read `docs/p0-build.md` (and `docs/pt-BR/p0-build.md` when working in Portuguese) for the qualification contract, then query GitHub live before reporting a PR/run status or starting/restarting a build.

Use these queries:

```sh
gh pr view <number> --json state,mergedAt,mergeCommit,headRefOid,url
gh run list --workflow p0-iso.yml --branch main --limit 20 --json databaseId,status,conclusion,headSha,createdAt,url
gh run view <run-id> --json status,conclusion,headSha,event,url,updatedAt
```

Before dispatching or rerunning P0, check for an existing queued/in-progress run for the same workflow and commit. A push-triggered run after merge is the canonical run; reuse it instead of dispatching a duplicate. Record the run ID and exact commit SHA in the handoff. If a duplicate is started accidentally, cancel it promptly, verify its terminal state, and disclose the mistake.

After a failure, inspect the failed step logs and published diagnostics/screenshots before changing code. Each fix must target a failure demonstrated by that evidence; do not rebuild on a speculative change. After completion, update the P0 checkpoint in both build-status documents.

Do not call an ISO verified merely because the image assembled or a smoke step passed. Require a successful P0 run, retrieve the artifact from that exact run, verify its checksum and build metadata, and report which qualification gates ran. QEMU evidence is not VirtualBox evidence; state that boundary explicitly.

## Handoffs

At every session boundary, preserve the exact PR/run IDs, commit SHA, last live-checked status, observed failure evidence, next action, and anything not yet verified in the P0 checkpoint. On resumption, re-query GitHub before acting; never treat the checkpoint as live state.
