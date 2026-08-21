# AI Company War — Codex Repository Instructions

本文件是 `D:/ai_company_war/game` 的跨 thread 持久工作流。每个 Codex thread 开工前必须完整读取本文件。

## 1. Authority and repository root

- 唯一 Godot/Git 项目根：`D:/ai_company_war/game`。不得在外层 `D:/ai_company_war` 初始化 Git、提交或推送。
- 最新用户明确指令优先；实际仓库事实优先于文档历史快照。
- `docs/CODEX_HANDOFF_V0_1.md` 是产品、架构、编码标准、Gate 与长期 Non-goals 的静态权威契约。
- `docs/CURRENT_TASK.md` 只是动态任务指针，不是产品权威，也不自行构成执行授权。
- `docs/task_packets/TP-XXX.md` 是单个任务的精确范围。一个 thread 只执行一个由用户明确授权的 TP。
- 任务包、路线图或自动生成的 prompt 仅是惰性文件。当前 thread 不得把自己生成的下一 prompt 当作新指令继续执行。

## 2. Mandatory reading and preflight

按以下顺序读取并核验：

1. `AGENTS.md`；
2. `docs/CURRENT_TASK.md`；
3. `CURRENT_TASK` 指向的唯一 Task Packet；
4. Task Packet 引用的 `docs/CODEX_HANDOFF_V0_1.md` 章节；首次进入项目、进入新 Gate、handoff 版本变化或发现冲突时完整阅读 handoff；
5. 实际项目文件、Git 根、分支、HEAD、工作树、remote/upstream、Godot 精确版本、main scene 与 renderer。

开工前必须记录：项目根、当前分支、起始 HEAD、`git status --short --branch`、remote 名称/去除凭据后的地址、upstream 和 Godot 版本。

以下任一情况立即停止，不得 stash、reset、clean、checkout、覆盖或顺手提交：

- 项目根不是 `D:/ai_company_war/game`；
- detached HEAD、分支与 Task Packet 不符；
- 有来源不明的 tracked/untracked 修改；
- `base_commit` 不存在或不是当前 HEAD 的祖先；
- 当前 HEAD 不是 `base_commit` 的唯一预期 handoff 子提交、提交主题不符，或存在额外未解释 commits；
- 当前 HEAD 在本 thread 工作期间被其他 thread 改变；
- 仓库事实、Task Packet、Architecture Contract 互相冲突；
- 当前 TP 要求 GitHub push，但 remote/upstream 缺失或目标不明确。

除首次配置 remote 的受控恢复外，新 TP 实现开始前还必须确认：工作树干净、`HEAD` 与 upstream SHA 完全一致。若本地领先、落后或分叉，停止；不得自动 pull/merge/rebase/force-push。

## 3. Authorization state machine

固定状态只有：

- `DRAFT_NOT_AUTHORIZED`：已生成，等待用户手动启动；
- `ACTIVE`：用户在当前 thread 明确授权执行；
- `AWAITING_USER_ACCEPTANCE`：自动验证通过，等待规定的试玩/人工 Gate；
- `ACCEPTED_FOR_PUBLICATION`：自动和必要人工验收均已通过，允许生成后继草案并准备 push；
- `BLOCKED`：触发 Stop Condition 或无法安全继续。

`COMPLETE` 是完成报告中的派生结论，不写进自引用的 handoff commit：只有 `ACCEPTED_FOR_PUBLICATION`、全部 closure commits 已普通 push、且远端目标 SHA 与本地 `HEAD` 相同这三项在运行时同时成立，才可报告 `TP Implementation Status: COMPLETE`。

`CURRENT_TASK` 或 Task Packet 中出现 `ACTIVE` 也不能替代当前用户授权。只有用户在当前 thread 明确发送“批准并执行 TP-XXX”或手动粘贴该包的 `Thread Start Prompt`，才授权该 TP 的写入、验证、提交和受限 push。

用户若只要求评审、解释或规划，不得修改文件、commit 或 push。

## 4. Implementation rules

- 只修改 Task Packet 的 `Files Allowed to Create/Modify`；额外工作必须停止并作为下一任务建议。
- 不预建后续 TP 的生产代码、空目录、占位类或未来系统。
- 保留用户修改；禁止破坏性 Git 命令和无审查的批量暂存。
- Godot 为 tracked `.gd` 生成的 `.gd.uid` 必须一同审查和版本控制；不得手写或删除正确 UID。
- 每个小步骤运行最窄验证；实现最终状态运行 Task Packet 的完整自动验证，并同时检查退出码、`Parse Error`、`SCRIPT ERROR`、`ERROR:`、UID、diff 和 Git 状态。
- 自动测试通过不等于用户试玩 Gate 通过，也不等于允许实施下一 TP。

## 5. Commit, acceptance, handoff, and push protocol

每个 TP 必须按以下顺序关闭：

1. **Validate implementation**：在最终实现上通过全部自动验收；失败则标记 `BLOCKED`，不生成正常后继 TP、不 push 失败快照。
2. **Implementation commit**：只显式暂存白名单文件；禁止无审查 `git add -A`。检查 `git diff --cached --name-status`、`git diff --cached --check` 和 staged diff，再创建 TP 实现 commit。
3. **Manual Gate**：若 Task Packet 有人工/试玩验收，更新状态为 `AWAITING_USER_ACCEPTANCE`，给出最短步骤并等待用户。未通过前不生成下一 TP、不 push、不声称 COMPLETE。失败修复使用新 commit，不 amend/reset 已用于验收的 commit。
4. **Accept for publication and generate exactly one successor**：只有当前 TP 自动与人工 Gate 真正通过后，把当前包标为 `ACCEPTED_FOR_PUBLICATION`，再基于实际仓库生成一个直接后继 `docs/task_packets/TP-NNN.md`，状态必须是 `DRAFT_NOT_AUTHORIZED`。不得批量生成路线中的多个包。
5. **Embed next-thread prompt**：后继 Task Packet 必须包含 `Thread Start Prompt`。该 prompt 明确说明：只有用户手动粘贴后才授权后继 TP；当前 thread 不得执行它。
6. **Update dynamic pointer**：把 `docs/CURRENT_TASK.md` 指向后继草案；记录前驱 TP、最终实现 commit、预期 handoff commit 主题、预期分支、remote/upstream 与 push policy。指针切换不等于授权；push 失败时后继仍不可执行。
7. **Handoff docs commit**：显式暂存当前 TP 的验收记录、唯一后继包、`CURRENT_TASK` 以及确有必要的状态文档，审查后创建一个独立 docs commit。该 commit 必须是最终 implementation commit 的直接子提交，主题必须与后继包中预先声明的 `expected_handoff_commit_subject` 完全一致；在下一 TP 前不得再混入其他 commit。不得把 handoff 自身未知 SHA 写进其内容。
8. **Final verification**：在最终 HEAD 重跑 Task Packet 指定的完整验证，确认工作树干净且没有未跟踪的正确 UID/交接文件。
9. **GitHub push**：只向已经存在、由用户明确确认的 GitHub remote/upstream 对当前分支执行普通 fast-forward push。push 成功后，比较远端目标分支 SHA 与本地 `HEAD`；只有相同才写 `Push Status: SUCCESS` 并把本 TP 派生为 `COMPLETE`。push 失败时，保留 `ACCEPTED_FOR_PUBLICATION` 和惰性的后继草案，报告 `BLOCKED`；不得授权或执行后继。
10. **Report and stop**：按 handoff 第 12 节报告，在报告中写入实际已推送的最终 handoff HEAD，原样给出后继包中的 `Thread Start Prompt`，明确后继包“已生成但未实施”，然后停止。

实现 commit 与 handoff docs commit 必须一起 push；任何交接 Markdown 都不能遗留在未提交工作树中。

## 6. GitHub safety boundary

用户已批准 TP-010 及以后在每个 TP 真正完成时 push 到 GitHub，但授权仅限以下边界：

- 使用已存在并经用户确认的 exact remote、upstream 和当前分支；
- 若尚无 remote，必须请用户提供精确 GitHub URL，并明确授权首次 `git remote add` / `git push -u`；不得猜测、搜索或自行创建远端仓库；
- 核实 remote host 是用户确认的 `github.com` 仓库或明确批准的 GitHub Enterprise host；报告时移除 URL 中的 userinfo、token 和敏感 query；
- 不创建或改变 GitHub 仓库可见性，不推 tag/release/其他分支；
- 禁止 `--force`、`--force-with-lease`、`--mirror`、`--all`、删除远端引用和任何历史重写；
- push 若因认证、网络、保护分支、non-fast-forward 或目标不一致而失败，保留本地 commit 并停止；不得自动 pull、merge、rebase、换 remote 或换分支绕过；
- remote URL、错误输出、Markdown 和完成报告不得泄露 token、用户名密码或其他凭据。

TP-000 的“不设置 remote、不 push”是已完成任务的历史边界；它不禁止在用户提供并确认 GitHub remote 后推送现有 TP-000 commits，也不禁止后续 TP 按本协议 push。

## 7. Required successor Task Packet fields

每个自动生成的后继 Task Packet 至少包含：

`Title / ID / Gate / Status / Authorization / Goal / Repository Facts / base_commit / expected_handoff_commit_subject / expected_commits_after_base / Player-visible Outcome / Files to Inspect / Files Allowed to Create / Files Allowed to Modify / Architecture Boundary / Implementation Steps / Acceptance Criteria / Automated Validation / Manual Validation / Non-goals / Stop Condition / Required Completion Report / Completion Protocol / Thread Start Prompt`。

`Thread Start Prompt` 必须包含项目根、TP ID、读取顺序、授权边界、preflight、测试/人工验收、commit/push、生成唯一后继包及停止规则。它还必须要求：当前 `HEAD` 的直接父提交等于 `base_commit`、当前提交主题等于 `expected_handoff_commit_subject`、`base_commit..HEAD` 恰好一个 commit、工作树干净且 `HEAD == upstream`；任何不符都停止。
