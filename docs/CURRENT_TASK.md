---
schema: acw-current-task-v1
task_id: TP-012
packet: docs/task_packets/TP-012.md
state: AWAITING_USER_ACCEPTANCE
predecessor_task: TP-011
base_commit: 02c68af0bb670997e4e98196b5caf3678519c108
expected_handoff_commit_subject: "docs(handoff): prepare TP-012 application dashboard"
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
- Baseline commit: `8f812aaaba3ea8185c3bad5639874dd0cc43173e`
- TP-000 implementation commit: `8f04c176523cdc947478745557e264849d1f3d9a`
- TP-010 implementation commit: `f5fec17360ecf445a279978a28a8c8477bf4469c`
- TP-011 starting handoff commit: `03f46417e96a7d15c84f160c501871d0b65b299d`
- TP-011 final implementation commit: `02c68af0bb670997e4e98196b5caf3678519c108`
- TP-011 status: `ACCEPTED_FOR_PUBLICATION`; `COMPLETE` is derived only after the final handoff push and remote-SHA verification
- Candidate next task: `TP-012` (`DRAFT_NOT_AUTHORIZED`)
- Confirmed remote: `origin` → `https://github.com/wangzianpaul-coder/ai-company-war.git`
- Confirmed upstream: `origin/main`

Actual repository facts always override this snapshot. A new thread must re-check them before writing.

## Authorization

This file does not authorize implementation. `TP-012` becomes active only when the user manually sends the `Thread Start Prompt` from `docs/task_packets/TP-012.md` in a new thread.

The TP-011 closeout is valid only after its implementation and handoff docs commits are ordinarily pushed and the live remote SHA is verified. A TP-012 thread may begin only when that publication closure succeeded, the worktree is clean and local `HEAD` exactly equals the confirmed `origin/main` SHA.

TP-012 may start only if all of the following are true: the current `HEAD` is the single direct child of `base_commit`, its commit subject exactly matches `expected_handoff_commit_subject`, `base_commit..HEAD` contains exactly one commit, the branch is `main`, the worktree is clean, and local `HEAD` equals the confirmed upstream SHA. This pins the generated prompt without trying to write a commit's own future SHA into that commit.

TP-012 remains inside G1. Neither this pointer nor passing TP-012 automation approves the G1 user Gate or authorizes TP-020/G2.

## Pointer update rule

After authorized TP-012 passes all automated validation and the user explicitly approves both its Manual Validation and the G1 Gate:

1. mark TP-012 `ACCEPTED_FOR_PUBLICATION` and record its final implementation commit;
2. generate exactly one direct successor `TP-020` as `DRAFT_NOT_AUTHORIZED`;
3. update this file to point to the successor;
4. create exactly one handoff docs commit as the direct child of the implementation commit, using the subject predeclared in the successor packet;
5. push all TP commits to the confirmed GitHub upstream and verify remote SHA equals local HEAD;
6. only after that runtime verification report TP-012 and G1 as complete, print the TP-020 packet's `Thread Start Prompt`, and stop without implementing it.

If TP-012 publication push fails, TP-012 remains `ACCEPTED_FOR_PUBLICATION`; the TP-020 file and pointer remain inert and must not be authorized or executed until a later safe push succeeds and `HEAD == upstream` is verified.
