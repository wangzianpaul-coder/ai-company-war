---
schema: acw-current-task-v1
task_id: TP-024
packet: docs/task_packets/TP-024.md
state: DRAFT_NOT_AUTHORIZED
predecessor_task: TP-023
base_commit: f162839a93f44ad0e9b81d041fdd69a3c22f6df6
expected_handoff_commit_subject: "docs(handoff): prepare TP-024 executive focus prototype"
expected_commits_after_base: 1
expected_branch: main
remote: origin
upstream: origin/main
push_policy: ORDINARY_FAST_FORWARD_AND_REMOTE_SHA_MATCH_REQUIRED
updated: 2026-08-27
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
- G2 Gate after TP-020: `NOT_YET_APPROVED`
- TP-020 publication state: `ACCEPTED_FOR_PUBLICATION`; `COMPLETE` is derived only after the final handoff push and remote-SHA verification
- TP-021 starting handoff commit: `16c4fed6f129d5b70226822e30756dda9f72e828`
- TP-021 final implementation commit: `4a90daad7cf4ab8a60137ddf71f0e9aa7d88e6e7`
- TP-021 automated/manual validation: `PASSED` / `PASSED_USER_CONFIRMED_2026-08-22`
- TP-021 publication state: `ACCEPTED_FOR_PUBLICATION`; `COMPLETE` is derived only after the final handoff push and remote-SHA verification
- G2 Gate after TP-021: `NOT_YET_APPROVED`; TP-021 acceptance does not approve H3 or the complete G2 Gate
- TP-022 starting handoff commit: `740131407da10b04d1dd8b18ab65a67b7d4fc95d`
- TP-022 final implementation commit: `3c52d66624ba9625289414a390020de0120618dc`
- TP-022 automated/manual validation: `PASSED` / `PASSED_USER_CONFIRMED_2026-08-25`
- TP-022 publication state: `ACCEPTED_FOR_PUBLICATION`; `COMPLETE` is derived only after the final handoff push and remote-SHA verification
- H4 / G2 Gate after TP-022: `NOT_YET_APPROVED`
- TP-023 starting handoff commit: `4a077125dbdce9158ed19f7e4a03f01de0d3bf8e`
- TP-023 initial implementation commit: `fdc8444188f3f42289649b82c1c5912c9cceb8fd`
- TP-023 final implementation commit after the separate UI/layout repair: `f162839a93f44ad0e9b81d041fdd69a3c22f6df6`
- TP-023 automated/manual validation: `PASSED` / `PASSED_USER_CONFIRMED_2026-08-27`
- TP-023 deterministic batch: 100 games / 600 quarters / 600 reports / 0 failures / 50+50 policies / 702 lines / digest `6c9631b7fa887be1512afce0a4ed4d574fe1ece0d8c92e4bb2106023c3b5ae32`
- TP-023 publication state: `ACCEPTED_FOR_PUBLICATION`; `COMPLETE` is derived only after the final handoff push and remote-SHA verification
- H1 / H3 / H4 / H6 / full G2 after TP-023: `NOT_YET_APPROVED`; TP-023 manual acceptance approves only its implementation slice
- TP-024 state: `DRAFT_NOT_AUTHORIZED`; generated as the unique inert successor and not implemented
- TP-024 scope: exactly five available player Executive Focus actions, exactly three selected per quarter and one whole-plan command for H2 evaluation; no sixth action, opponent Focus, win/loss, G3 or complete-G2 approval
- Confirmed remote: `origin` -> `https://github.com/wangzianpaul-coder/ai-company-war.git`
- Confirmed upstream: `origin/main`

Actual repository facts always override this snapshot. A new thread must re-check them before writing.

## Authorization

This file does not authorize implementation. `TP-024` becomes active only under an explicit future current-thread user instruction that names and authorizes TP-024; manually sending the packet's stored `Thread Start Prompt` is the normal reusable authorization text.

The TP-023 closeout is valid only after its implementation and handoff docs commits are ordinarily pushed and the live remote SHA is verified. TP-024 implementation may begin only when that publication closure succeeded, the worktree is clean and local `HEAD` exactly equals the confirmed `origin/main` and live remote SHA.

TP-024 may start only if current `HEAD` is the single direct child of `base_commit`, its subject exactly matches `expected_handoff_commit_subject`, `base_commit..HEAD` contains exactly one commit, the branch is `main`, the worktree is clean, and local `HEAD` equals the confirmed upstream and live remote SHA. This pins the generated prompt without writing the handoff commit's own future SHA into its contents.

TP-024 is only an inert draft for the bounded five-select-three player Executive Focus H2 experiment. Neither this pointer nor its generated packet authorizes TP-024 production code, TP-025, a sixth action, opponent Focus planning, an independent win/loss system, H2/H4/full-G2 approval, G3 or any adjacent function.

## Pointer update rule

After a separately authorized TP-024 passes complete automated validation, receives explicit implementation acceptance and receives an explicit user H2 classification:

1. mark TP-024 `ACCEPTED_FOR_PUBLICATION` and record its actual final implementation commit, validation facts and H2 result while retaining the separate G2 status;
2. generate exactly one full direct successor `TP-025` as `DRAFT_NOT_AUTHORIZED`, with scope derived from the actual H2/G2 evidence;
3. update this file to point to that successor;
4. create exactly one handoff docs commit as the direct child of the final TP-024 implementation commit, using the subject predeclared in the successor packet;
5. run final validation, ordinary-push all TP commits to the confirmed GitHub upstream and verify the live remote SHA equals local HEAD;
6. only after that runtime verification report TP-024 as complete and keep TP-025 inert unless a newer current user instruction explicitly authorizes it.

If TP-023 publication push fails, TP-023 remains `ACCEPTED_FOR_PUBLICATION`; this TP-024 packet and pointer remain inert and must not be executed until a later safe ordinary push succeeds and `HEAD == upstream == live remote` is verified. Do not pull, merge, rebase, reset or change the remote to bypass a publication failure.
