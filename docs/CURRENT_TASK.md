---
schema: acw-current-task-v1
task_id: TP-021
packet: docs/task_packets/TP-021.md
state: DRAFT_NOT_AUTHORIZED
predecessor_task: TP-020
base_commit: b19987fbf35e018a98f4030c8139acf7f00141a4
expected_handoff_commit_subject: "docs(handoff): prepare TP-021 two-market economy"
expected_commits_after_base: 1
expected_branch: main
remote: origin
upstream: origin/main
push_policy: ORDINARY_FAST_FORWARD_AND_REMOTE_SHA_MATCH_REQUIRED
updated: 2026-08-22
---

# Current Task Pointer

## Current repository facts

- Project/Git root: `D:/ai_company_war/game`
- Baseline commit: `8f812aaaba3ea8185c3bad5639874dd0cc43173e`
- TP-000 implementation commit: `8f04c176523cdc947478745557e264849d1f3d9a`
- TP-010 implementation commit: `f5fec17360ecf445a279978a28a8c8477bf4469c`
- TP-011 starting handoff commit: `03f46417e96a7d15c84f160c501871d0b65b299d`
- TP-011 final implementation commit: `02c68af0bb670997e4e98196b5caf3678519c108`
- TP-012 starting handoff commit: `06107e7126c07f555d99093449474ca9371c82d2`
- TP-012 final implementation commit: `a2fdef1e6e43691282ffbc1068a607bf96e2eb28`
- TP-012 automated/manual validation: `PASSED` / `PASSED_USER_CONFIRMED_2026-08-21`
- G1 Gate: `PASSED_USER_APPROVED_2026-08-21`
- TP-012 publication state: `ACCEPTED_FOR_PUBLICATION`; `COMPLETE` is derived only after the final handoff push and remote-SHA verification
- TP-020 starting handoff commit: `4459173e179014065512a9e4e55eb26836bdc8eb`
- TP-020 final implementation commit: `b19987fbf35e018a98f4030c8139acf7f00141a4`
- TP-020 automated/manual validation: `PASSED` / `PASSED_USER_WAIVED_2026-08-22`
- G2 Gate: `NOT_YET_APPROVED`
- TP-020 publication state: `ACCEPTED_FOR_PUBLICATION`; `COMPLETE` is derived only after the final handoff push and remote-SHA verification
- Candidate next task: `TP-021` (`DRAFT_NOT_AUTHORIZED`)
- Confirmed remote: `origin` → `https://github.com/wangzianpaul-coder/ai-company-war.git`
- Confirmed upstream: `origin/main`

Actual repository facts always override this snapshot. A new thread must re-check them before writing.

## Authorization

This file does not authorize implementation. `TP-021` becomes active only under an explicit current-thread user instruction that names or unambiguously authorizes TP-021; the stored `Thread Start Prompt` is the normal reusable authorization text.

The TP-020 closeout is valid only after its implementation and handoff docs commits are ordinarily pushed and the live remote SHA is verified. TP-021 implementation may begin only when that publication closure succeeded, the worktree is clean and local `HEAD` exactly equals the confirmed `origin/main` SHA.

TP-021 may start only if all of the following are true: the current `HEAD` is the single direct child of `base_commit`, its commit subject exactly matches `expected_handoff_commit_subject`, `base_commit..HEAD` contains exactly one commit, the branch is `main`, the worktree is clean, and local `HEAD` equals the confirmed upstream SHA. This pins the generated prompt without trying to write a commit's own future SHA into that commit.

TP-021 is the two-market economy slice. Neither this pointer nor its generated packet authorizes TP-021 production code, TP-022 opponent AI/RNG, TP-023 six-quarter Prototype/report/batch simulation or any adjacent function.

## Pointer update rule

After separately authorized TP-021 passes all required validation and acceptance:

1. mark TP-021 `ACCEPTED_FOR_PUBLICATION` and record its final implementation commit;
2. generate exactly one direct successor `TP-022` as `DRAFT_NOT_AUTHORIZED`;
3. update this file to point to the successor;
4. create exactly one handoff docs commit as the direct child of the implementation commit, using the subject predeclared in the successor packet;
5. push all TP commits to the confirmed GitHub upstream and verify remote SHA equals local HEAD;
6. only after that runtime verification report TP-021 as complete and keep the TP-022 draft inert unless a current user instruction explicitly authorizes continuation.

If TP-020 publication push fails, TP-020 remains `ACCEPTED_FOR_PUBLICATION`; the TP-021 file and pointer remain inert and must not be executed until a later safe push succeeds and `HEAD == upstream` is verified.
