---
schema: acw-current-task-v1
task_id: TP-011
packet: docs/task_packets/TP-011.md
state: DRAFT_NOT_AUTHORIZED
predecessor_task: TP-010
base_commit: f5fec17360ecf445a279978a28a8c8477bf4469c
expected_handoff_commit_subject: "docs(handoff): prepare TP-011 finance and project core"
expected_commits_after_base: 1
expected_branch: main
remote: origin
upstream: origin/main
push_policy: ORDINARY_FAST_FORWARD_AND_REMOTE_SHA_MATCH_REQUIRED
updated: 2026-08-21
---

# Current Task Pointer

## Current repository facts

- Project/Git root: `D:/ai_company_war/game`
- TP-010 status: `ACCEPTED_FOR_PUBLICATION`; runtime completion still requires the final handoff push and remote-SHA verification
- Baseline commit: `8f812aaaba3ea8185c3bad5639874dd0cc43173e`
- TP-000 implementation commit: `8f04c176523cdc947478745557e264849d1f3d9a`
- TP-010 implementation commit: `f5fec17360ecf445a279978a28a8c8477bf4469c`
- Candidate next task: `TP-011` (`DRAFT_NOT_AUTHORIZED`)
- Confirmed remote: `origin` → `https://github.com/wangzianpaul-coder/ai-company-war.git`
- Confirmed upstream: `origin/main`

Actual repository facts always override this snapshot. A new thread must re-check them before writing.

## Authorization

This file does not authorize implementation. `TP-011` becomes active only when the user manually sends the `Thread Start Prompt` from `docs/task_packets/TP-011.md` in a new thread.

The TP-010 closeout must first be ordinarily pushed and verified. A TP-011 thread may begin only when the worktree is clean and local `HEAD` exactly equals the confirmed `origin/main` SHA.

TP-011 may start only if all of the following are true: the current `HEAD` is the single direct child of `base_commit`, its commit subject exactly matches `expected_handoff_commit_subject`, `base_commit..HEAD` contains exactly one commit, the branch is `main`, the worktree is clean, and local `HEAD` equals the confirmed upstream SHA. This pins the generated prompt without trying to write a commit's own future SHA into that commit.

## Pointer update rule

After an authorized TP passes all automated and required user validation:

1. mark the completed packet `ACCEPTED_FOR_PUBLICATION` and record its final implementation commit;
2. generate exactly one direct successor packet as `DRAFT_NOT_AUTHORIZED`;
3. update this file to point to the successor;
4. create exactly one handoff docs commit as the direct child of the implementation commit, using the subject predeclared in the successor packet;
5. push all TP commits to the confirmed GitHub upstream and verify remote SHA equals local HEAD;
6. only after that runtime verification report the predecessor TP as `COMPLETE`, print the successor packet's `Thread Start Prompt`, and stop without implementing it.

If push fails, the predecessor remains `ACCEPTED_FOR_PUBLICATION`; the successor file and pointer remain inert and must not be authorized or executed until a later safe push succeeds and `HEAD == upstream` is verified.
