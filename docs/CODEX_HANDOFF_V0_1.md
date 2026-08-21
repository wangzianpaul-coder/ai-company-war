# AI Company War — Codex 权威实施提示与门控计划 v0.1

> 本文件是 AI Company War 当前阶段对 Codex 的权威实施说明。Codex 应先检查现有仓库，再根据本文件直接修改项目文件，而不是让用户手动复制代码或重复创建 UI 节点。

| 字段 | 当前值 |
|---|---|
| 文档 ID | `ACW-CODEX-HANDOFF-0.1` |
| 权威日期 | 2026-08-21 |
| Godot 项目根目录 | `D:/ai_company_war/game` |
| 本文件权威路径 | `D:/ai_company_war/game/docs/CODEX_HANDOFF_V0_1.md` |
| 阶段 A 状态 | 15 项 Decision Gate 已全部按推荐批准 |
| 当前开发 Gate | `G0 / M0：Repository Safety Baseline` |
| 当前可执行任务 | `TP-000：Git 与自动验证基线` |
| 当前禁止事项 | 在 TP-000 验收前修改游戏逻辑、场景或项目配置 |

## 权威性声明

1. 用户已于 2026-08-21 明确批准阶段 A 的全部推荐。本文件中的 `Approved Decisions` 是当前有效状态，覆盖 `STAGE_A_RESEARCH_AND_DESIGN.md` 开头“等待产品决策、尚未进入阶段 B”的旧状态。
2. `early_plan.md` 是早期需求与研究任务的来源，不是后续实现规格。它与本文件冲突时，以用户最新指令和本文件为准。
3. `STAGE_A_RESEARCH_AND_DESIGN.md` 是研究依据和设计附录，不是当前 Task Packet。Codex 不得从其中挑选尚未进入当前 Gate 的功能顺便实现。
4. 实际仓库事实优先于文档中的历史快照。若文件、Git 状态、Godot 版本或用户修改与本文件不一致，先报告差异；不得为了让仓库“符合文档”而覆盖实际文件。
5. 用户在当前任务中的最新明确要求永远高于本文件。若最新要求只让 Codex 评审、解释或规划，则本文件本身不构成写入授权。
6. 本文件只维护一份权威副本。不要在 `D:/ai_company_war/docs` 或其他位置复制第二份，以免版本漂移。

---

# 0. 给 Codex 的主提示

当用户说“按照 handoff 执行”“开始当前任务”或同义指令时，Codex 必须按下列协议工作：

1. 完整阅读本文件，不只读取 `TP-000`。
2. 检查项目根、全部现有文件、`AGENTS.md`（如果后来出现）、Git 根与状态、Godot 精确版本、主场景和 renderer。
3. 明确区分：
   - `Repository Fact`：本次亲自核实的事实；
   - `Approved Decision`：用户已确认的产品/技术方向；
   - `Validation Hypothesis`：必须通过 Prototype 或试玩验证，不能包装成已证明事实；
   - `Current Authorization`：本次唯一允许执行的 Task Packet。
4. 先给出简短执行计划，再只实施“当前可执行任务”。不得因为未来目录和架构已经写明，就一次性创建全部脚手架。
5. 直接编辑获准的 `.gd`、`.tscn`、`.tres`、JSON、文档或项目配置；不得默认要求用户复制代码、逐个新建节点或手工连接 Signal。
6. 修改前先建立当前 Task 要求的恢复点；保留用户已有文件与未知修改。
7. 每完成一个小步骤就运行最窄的相关验证，任务末尾运行完整指定验证。
8. 任何失败都必须保留原始错误、退出码和受影响文件。不得用扩大重构范围的方式掩盖失败。
9. 达到当前 Gate 后停止，按第 12 节格式汇报。只建议下一任务，不自动执行下一任务。

总停止规则：

> 在 M0 初始 Git 恢复点存在且基线验证通过之前，Codex 不得修改 `project.godot`、`main.gd`、`main.tscn`，也不得创建游戏模拟系统。若仓库事实与本文不符、存在来源不明的用户修改、命令失败、版本/renderer 不符或完成任务需要突破 Architecture Contract，立即停止相关写入并报告，不自行猜测、删除、覆盖或扩大范围。

---

# 1. 项目目标

## 1.1 Product Identity

`AI Company War` 是一款面向 Windows PC / Steam 的单人离线、季度回合制 AI 产业经营策略游戏。

玩家扮演一家**完全虚构 AI 公司的创始 CEO**。公司经营是核心，简化的产业网络是外部战场。玩家通过有限的高层注意力、现金、算力和人才容量，在模型研发、服务增长、成本、安全、开放策略和市场竞争之间下注。

一句话产品定义：

> 经营一家虚构 AI 公司：争夺算力与人才，训练并发布模型，在开放与闭源、增长与毛利、速度与安全之间下注，并在对手、宕机与监管夹击下建立可持续的产业地位。

这款游戏：

- 是季度制 `AI industry war room`；
- 是公司级资源分配、长期承诺、共同市场和对手反制的模拟；
- 吸收 Roguelite 的短战役节奏、情境变化和重玩结构；
- 不是缩小版 Paradox；
- 不是 `Startup Company` 式组件制造/办公室点击器；
- 不是牌库构筑游戏；
- 不是现实公司新闻模拟器。

## 1.2 核心玩家幻想

玩家应感到自己在：

- 提前数季度识别算力、现金或可靠性瓶颈；
- 在短暂技术领先窗口关闭前作出不可逆或有锁定期的下注；
- 用发布、定价、开放策略和渠道，把技术优势转成真实商业地位；
- 读懂对手的公开信号并进行经济反制；
- 承受“用户增长很好，但推理成本、容量和事故风险同时恶化”的压力；
- 从季度报告中理解成功或失败，而不是猜隐藏公式。

玩家不应感到自己在：

- 反复制造 Backend/UI/Research Component；
- 逐个管理员工座位、情绪、饮食和日程；
- 逐台摆放服务器、机架或芯片；
- 控制国家、军队、领土或外交；
- 抽牌、构筑牌库或等待随机卡决定本季能做什么；
- 对着几十个 1% 滑杆寻找唯一公式。

## 1.3 Core Loop（核心循环）

~~~mermaid
flowchart LR
    A[外部环境与 Frontier Clock 变化] --> B[Briefing 获取市场 对手 风险信息]
    B --> C[制定季度策略]
    C --> D[分配现金 算力 三类人才]
    D --> E[提交最多 3 个 Executive Focus 行动]
    E --> F[同步执行 3 个 Simulation Tick]
    F --> G[模型 项目 市场 财务 风险变化]
    G --> H[对手行动与事件]
    H --> I[可解释 Quarter Report]
    I --> A
~~~

一个完整季度的目标体验：

~~~text
Briefing
→ 查看市场、对手、风险和到期项目
→ 选择最多 3 个公司级重大行动
→ 分配现金、算力和 Research / Systems / Product-GTM 人才容量
→ Commit
→ 玩家、对手、项目、市场、财务和风险按 3 个月结算
→ 对手公开行动或发出未来信号
→ Quarter Report 展示前值、后值、前三原因、机会成本和下一季风险
~~~

## 1.4 Meta Loop（长期循环）

~~~text
建立初始能力
→ 训练并发布一代模型
→ 抢占细分市场或开发者生态
→ 形成现金流、合同、渠道和组织能力
→ 技术前沿继续移动，旧优势折旧
→ 调整开放路线、基础设施与市场定位
→ 经历融资、容量、安全和监管危机
→ 在期限内完成 Board Mandate
→ 保持财务存续与独立，或进入失败结局
~~~

## 1.5 玩家体验尺度

| 现实时间 | 玩家行为 | 设计目标 |
|---|---|---|
| 每约 30 秒 | 比较一个行动的成本、预期区间、机会成本、锁定期和风险 | 每次点击都回答一个战略问题 |
| 每约 5 分钟 | 完成计划、提交、结算、对手回应和报告的季度循环 | 形成清晰的计划—结果—新问题闭环 |
| 每约 30 分钟 | 推进 5–8 季度，完成一次模型训练/发布并经历一次危机 | 形成一段有高潮的公司故事 |

## 1.6 胜负目标

- 战役目标：在期限内完成一个 `Board Mandate`，同时保持公司独立和财务存续。
- 失败包括：破产、被迫出售、关键市场禁入或失去独立控制。
- 估值是派生结果，不是唯一胜利分，也不是可直接消费的资源。
- 模型领先是短期窗口；长期优势来自组织能力、合同、渠道、生态和 Trust。

## 1.7 当前开发目标

当前只处于 `G0 / M0`：

> 在不改变现有游戏行为的前提下，为项目建立 Git 恢复点、准确的运行说明和能以退出码判断成功/失败的最小自动验证入口。

M0 不增加玩法。第一次新增现金、收入/成本、项目进度和纯模拟季度闭环属于后续 M1。训练/推理容量、两个市场和对手属于 M2。

---

# 2. 已知项目状态

## 2.1 2026-08-21 已核实事实

| 项目 | 已核实状态 |
|---|---|
| Workspace 根 | `D:/ai_company_war` |
| Godot 项目根 | `D:/ai_company_war/game` |
| 引擎 | 普通 Godot Engine，不使用 .NET |
| 精确版本 | `4.7.1.stable.official.a13da4feb` |
| 脚本语言 | GDScript |
| 主场景 | `res://main.tscn` |
| Renderer | `GL Compatibility` |
| 初期平台 | Windows PC / Steam |
| Git | Workspace 和 `game` 当前均无 `.git` |
| Git 客户端 | `git version 2.55.0.windows.4` 已安装 |
| 测试 | 尚无 `tests/` 或测试 runner |
| 插件 | 尚无 `addons/`、GDExtension 或第三方测试插件 |
| 导出 | 尚无 `export_presets.cfg`，不得编造构建/Steam 导出命令 |

已知本地引擎路径：

~~~text
D:/ai_company_war/Godot_v4.7.1-stable_win64.exe
D:/ai_company_war/Godot_v4.7.1-stable_win64_console.exe
~~~

## 2.2 M0 开始前应存在的项目文件

~~~text
res://
├── .editorconfig
├── .gitattributes
├── .gitignore
├── .godot/                         # 生成缓存，已被 .gitignore 忽略
├── icon.svg
├── icon.svg.import
├── main.gd
├── main.gd.uid
├── main.tscn
├── project.godot
└── docs/
    ├── .gdignore
    └── CODEX_HANDOFF_V0_1.md
~~~

如果 M0 实际开始时出现其他文件，不要自动认定它们错误；先判断是否为用户在阶段 B 后新增的工作，并报告。

## 2.3 当前场景与脚本行为

- `project.godot` 的 `run/main_scene` 指向 `main.tscn`。
- `config/features` 包含 `4.7` 和 `GL Compatibility`。
- `renderer/rendering_method` 与 mobile renderer 都是 `gl_compatibility`。
- `main.tscn` 根节点是全屏 `Control`，背景使用全屏 Anchor。
- `TitleLabel`、`DateLabel`、`StartButton` 仍使用绝对 offset；这是已知技术债，不在 M0 修复。
- `main.gd` 继承 `Control`，日期状态和季度推进仍直接位于 UI 脚本中；这是一次性草图，不是未来架构范例。
- 启动时标题为 `AI COMPANY WAR`，日期为 `2026 Q1`，按钮为 `START GAME`。
- 第一次点击按钮只把文字变为 `NEXT QUARTER`，日期仍为 Q1。
- 第二次及之后的点击推进季度；Q4 后进入下一年 Q1。

## 2.4 阶段 B 快照 Hash

这些 SHA-256 只用于识别阶段 B 之后是否出现变化，不用于覆盖新修改：

| 文件 | SHA-256 |
|---|---|
| `project.godot` | `C0EAEF8C351D66366DCD4A4D48612E8570C6E7A889168DC7E0FCE30E99E99393` |
| `main.tscn` | `54F601FDCAAFDCAD045CCA1217DA6B7918D76EFA4F4FBFDA2DADA258EE7C3F24` |
| `main.gd` | `ED84661952E42B1E52172270E7156401319A0805B53F202821624B1EF301BB36` |

Hash 不一致意味着“仓库在本文件后发生过变化”，不是自动删除或还原的理由。

## 2.5 当前已验证的基线

截至本文件生成时，以下检查已返回 0：

- Godot 精确版本查询；
- Headless import；
- `main.gd` `--check-only` 解析；
- 指定 `res://main.tscn` 的 headless scene smoke；
- 主项目 headless 启动。

M0 仍必须重新运行这些命令。历史成功不等于本次修改通过。

## 2.6 Codex 每次开工前必须重新检查

1. 当前目录和 `project.godot` 的真实位置；
2. 从项目目录向父级查找是否已有 Git 根；
3. `git status`、未跟踪文件和用户修改；
4. 是否出现 `AGENTS.md`、README 或更高优先级说明；
5. Godot 精确版本，而不仅是文件名；
6. main scene、renderer 和项目配置；
7. 当前文件列表与 Hash 差异；
8. 当前任务允许修改的精确文件；
9. 基线命令是否仍通过；
10. 无法确认的状态不得编造。

---

# 3. 已批准设计决策

以下全部是 `Approved Decision`，不再是 Open Question：

| # | 决策 | 已批准结论 |
|---:|---|---|
| 1 | 产品方向 | AI 产业战争室：公司经营核心 + 简化产业网络；吸收 Roguelite 节奏，但不做纯卡牌 |
| 2 | 玩家身份 | 完全虚构 AI 公司创始 CEO |
| 3 | 时间与行动 | 季度回合；每季度内部恰好 3 个 月 Simulation Tick；每季 3 个 Executive Focus |
| 4 | 战役长度 | Prototype 6 季度；Vertical Slice 8 季度/30–45 分钟；MVP 24 季度；1.0 为 32 季度/3–6 小时 |
| 5 | 胜负结构 | 期限内完成 Board Mandate，同时保持独立与财务存续；VS 先做一个使命 |
| 6 | 签名系统 | Frontier Clock + 训练/推理容量争夺 + 推理单位经济 + 开放/闭源 |
| 7 | 市场范围 | VS：Consumer Assistant + Developer/API；MVP 再加入 Enterprise |
| 8 | 对手 AI | 合法性规则过滤 + 人格目标 + 可解释 Utility AI + 小幅 Seeded noise |
| 9 | UI/视觉 | 固定 2D Dashboard/Game Shell；无地图、无 3D；少量虚构静态立绘和轻量 2.5D 动效 |
| 10 | 公司/IP | 官方基础包全部虚构，不做明显谐音影射；现实内容只保留未来授权包/社区包的可能 |
| 11 | 平台功能 | Windows/Steam、单人离线优先；无多人、无 Live LLM、无实时新闻 |
| 12 | Data/Mod | 第一方 typed `.tres`；版本化 JSON 存档；CSV 本地化；Data-driven Design，但 Workshop 延后 |
| 13 | Renderer | 保留实际 `GL Compatibility`；只有具体高级 2.5D 场景证明需要时才单独测试 Forward+ |
| 14 | 商业定位 | 1.0 基准价 $19.99；EA 仅在 MVP 当前可售时考虑 $16.99；Demo 先行 |
| 15 | 开发治理 | 先建立 handoff；首个实施包在 `game` 初始化 Git 与测试基线；按 Gate 小步实施，不一次开发整款游戏 |

## 3.1 已批准的核心系统约束

- 规划阶段天然暂停；提交后同步结算。
- Executive Focus 表示高层注意力，不替代现金、人才和算力。
- 常规资源分配不消耗 Focus，但长期项目存在锁定期和换队损失。
- Talent 首版聚合为 `Research`、`Systems`、`Product/GTM` 三类容量池。
- Compute Capacity 是每月可分配容量，由训练、在线推理和必要预留共同争用；不是可囤积金币。
- 模型至少具有 `Capability`、`Inference Efficiency`、`Reliability`、`Safety` 四维。
- Market Share、Valuation、Investor Confidence、Research Capability 等主要是派生指标，不允许直接购买。
- 对手只能读取季度提交前的可观察快照，不能偷看玩家本季度未公开 Command。
- 对手重大训练、扩容或进入市场必须有公开行为或预警信号；AI 决策保存主要 `reason_key`。
- 任何重大数值变化必须生成同源 `EffectContribution`；UI、报告、Debug 与测试消费同一实际结果，不得各写一套解释。
- 每季度原则上最多一个 `Must Respond` 事项。
- Event 通过统一效果解析器改变状态，不能直接操纵 UI，也不能伪造本应由市场/财务系统产生的结果。

## 3.2 仍需验证的设计假设

以下方向已经批准进入 Prototype，但尚未被证明好玩：

| ID | Validation Hypothesis | 最早 Gate |
|---|---|---|
| H1 | 训练和推理争用同一容量能产生痛苦但公平的选择 | G2 |
| H2 | 每季度 3 个 Executive Focus 足够丰富且不过载 | G2 |
| H3 | Consumer 与 Developer/API 的权重差异能产生两条路线 | G2 |
| H4 | 对手信号和解释让玩家感到被竞争，而不是被随机惩罚 | G2 |
| H5 | Frontier Clock 促进及时商业化，而不是制造无力感 | G2–G3 |
| H6 | Quarter Report 能在 30–60 秒内解释关键变化 | G2–G3 |
| H7 | 8 季度能形成 30–45 分钟且有高潮的 Vertical Slice | G3 |

Codex 不得把这些假设写成不可调整的引擎常量；实现应支持低成本试验，并在 Gate 失败时停下来调整设计。

## 3.3 新机制准入测试

一个新机制至少满足以下四项中的三项，才可建议进入游戏：

1. 消耗真正稀缺且有替代用途的资源；
2. 产生延迟、锁定或不可逆承诺；
3. 改变对手或共同市场的选择；
4. 结果与失败原因可解释。

只增加字段、资源名、页面、事件数量或 1% 修正不算新的战略深度。

---

# 4. Architecture Contract

本节是硬契约。若获准任务确实需要改变它，Codex 必须先提出 Architecture Decision，说明原因、替代、迁移和测试影响；不得在实现中静默突破。

## 4.1 总体结构

采用 `modular monolith`，不提前拆插件、服务、数据库或微服务。

~~~mermaid
flowchart TB
    ROOT[Composition Root / main.tscn] --> UI[Presentation / Control Scenes]
    ROOT --> APP[Application / GameSession]
    ROOT --> CONTENT[Content Registry / read-only Resources]
    ROOT --> SAVE[Persistence]
    UI --> APP
    APP --> SIM[Simulation Domain]
    APP --> SAVE
    SAVE --> STATE
    SIM --> STATE[Runtime Game State]
    SIM --> CONTENT
    SIM --> RNG[Versioned Simulation RNG]
    SIM --> RESULT[TickResult / ordered Domain Events / Effects]
    RESULT --> APP
    APP -. committed typed signals .-> UI
    TEST[Headless Tests and Debug] -. verifies .-> APP
    TEST -. verifies .-> SIM
    TEST -. validates .-> CONTENT
~~~

## 4.2 层级依赖矩阵

| 层 | 主要职责 | 允许依赖 | 明确禁止 |
|---|---|---|---|
| Composition Root | 创建并注入模块，装配初始页面 | 各模块公开构造接口 | 经济公式、AI 评分、随机抽取、Save 字段迁移 |
| Presentation/UI | 显示 View Model、收集输入、提交 Command | `Control`、Application API、只读 View Model | 直接引用 Simulation System；直接改 Game State；在按钮回调结算现金/市场/项目 |
| Application | 持有 GameSession，验证用例阶段，调用模拟、提交成功结果、协调存档 | Simulation facade、Command/Result、Content Registry、Persistence 接口 | 具体 Label/Button/节点路径；经济公式；页面场景依赖 |
| Simulation Domain | 月 Tick、季度结算、项目、市场、AI、事件、不变量 | Runtime State、只读 Definition、注入 RNG、Command | `Node`、`SceneTree`、`Control`、`Input`、`Time`、`OS`、`FileAccess`、Autoload、UI、存档实现 |
| Runtime State | 当前局 typed 状态和实体数据 | 基础值、稳定 ID、State 类型 | System、UI、文件 API、Node、可变 Resource |
| Content Data | 公司、行动、项目、事件和平衡定义 | typed Resource Schema、稳定 ID、内容验证 | 当前局状态、UI 节点、运行中修改共享 Resource |
| Persistence | State↔DTO、JSON、迁移与安全写入 | `snapshot_mapper.gd` 可依赖只读 Runtime State 类型；其余模块只依赖 Snapshot DTO、基础值、`FileAccess`、迁移器 | 保存 Node/Resource/Callable/Signal/实例 ID；执行经济公式；失败加载污染活动 Session |
| Domain Events | 已结算事实、有序事件和 Effect 明细 | 基础值、稳定 ID、localization key | 通过监听器顺序修改模拟；使用全局 Event Bus 驱动资金链 |
| AI Decision | 从提交前快照生成合法 Command 和原因 | 只读快照、Command、人格定义、`ai` RNG | 偷看未公开玩家命令；绕过合法性校验；直接改 State |
| Debug/Tests | 检验生产层、内容和场景 | 所有生产层 | 被任何生产代码反向依赖 |

Persistence 内部边界：

- `persistence/snapshot_mapper.gd` 是 Persistence 中唯一允许引用 typed Runtime State 的模块；它可只读映射活动 State，并可从已验证 DTO 构造一套新的 State 对象图，但不得修改活动 GameSession。
- `save_repository.gd`、`save_codec.gd` 与 `migrations/` 只处理 DTO、基础值和文件边界，不依赖 Runtime State 或 Simulation System。
- Simulation Domain 永远不依赖 Persistence；Application 负责把 State/DTO 交给两侧边界。

## 4.3 标准调用链

~~~text
UI callback
→ 构造 typed GameCommand
→ GameSession.submit_command()
→ Command validation
→ SimulationEngine.advance_quarter(active_state, commands)
→ 在隔离 working state 中执行 3 个 month tick
→ 验证不变量
→ 返回 TickResult(new_state, ordered_events, effect_breakdown)
→ GameSession 原子提交 new_state
→ Application 发出已提交 typed signal
→ Presenter 生成 View Model
→ UI 刷新
~~~

- UI callback 只能构造 Command、调用 Application 和刷新表现。
- 活动状态在全部结算与验证成功前不得暴露部分修改。
- 失败结果不得留下“钱已扣除但项目未创建”等半提交状态。
- 不建立全局 Event Bus。Signal 只通知已提交结果，不决定核心结算顺序。

## 4.4 时间与公平结算

基础模拟单位是月；一个季度固定执行 3 次手动月 Tick。`_process(delta)` 只用于 UI 动画、插值和输入，经济结果不得依赖帧率。首版模拟单线程。

推荐稳定顺序：

1. 从已提交状态建立本季度 `planning_snapshot`；
2. 验证玩家 Command，但不修改活动状态；
3. 所有对手从同一份可观察 `planning_snapshot` 生成 Command 和原因；
4. 以明确优先级、提交序号和稳定实体 ID 排序全部合法 Command；
5. 复制/映射为隔离的 working state；
6. 应用季度开始 Command；
7. 连续执行 3 个月：到期效果 → 项目 → 容量/运营 → 财务 → 市场/风险；
8. 第 3 月后抽取季度事件、更新冷却和 Frontier Clock；
9. clamp 并验证全部不变量；
10. 生成有序 DomainEvent 与 EffectContribution；
11. 只有成功时才提交新状态并增加季度。

M2 实现时可以通过 Architecture Decision 微调内部系统顺序，但以下不可改变：

- 玩家和 AI 使用同一提交前公开状态；
- AI 不偷看未公开 Command；
- 顺序有稳定 tie-breaker；
- 失败不留下部分状态；
- 报告来自真实结算明细。

## 4.5 数值与确定性

承诺范围：

> 同 Godot `4.7.1.stable.official.a13da4feb`、同规则版本、同内容摘要、同 master seed 和同 Command 序列，得到相同结果。

不承诺跨 Godot 大版本或任意平台的 bit-perfect 重放。

规则：

- 金钱使用整数最小单位；命名必须带单位，如 `cash_cents`。
- 比例、概率和市场份额使用 basis points；10000 bps = 100%。
- 每次整数除法明确舍入方向，每个边界明确 clamp。
- 决定 AI/事件/经济的权重使用整数累计抽签；float 只用于 UI 表现。
- 模拟禁止全局 `rand*()`；RNG 由构造注入。
- 至少使用 `ai`、`events`、`market` 三个命名 RNG stream，并分别保存状态。
- 不使用 `hash()`、`Dictionary.hash()`、对象 instance ID、目录顺序或线程完成顺序生成持久 ID、RNG 子流或 Golden digest。
- 参与结算的实体、定义和并列候选项必须按稳定 ID 排序并提供 tie-breaker。
- Canonical snapshot 使用明确字段顺序和 SHA-256。
- 64 位 seed/state 在 JSON 中使用严格校验的十六进制或十进制字符串，避免超过 2^53 的精度损失。
- Simulation 禁止系统时间、帧 delta 和未归并的线程结果。

## 4.6 Godot 对象选择

| 类型 | 使用 | 禁止/避免 |
|---|---|---|
| Scene / Node | Game Shell、页面、Modal、Toast、图表、音频、Composition Root | 公司、市场、项目、经济系统实体 |
| typed `RefCounted` | Simulation Engine、State、System、Command、Result、DomainEvent | 需要 SceneTree 生命周期或绘制的对象 |
| Custom Resource | 只读 Company/Action/Project/Event/Balance Definition | Cash、AI 记忆、项目进度等 Runtime State |
| typed Dictionary | ID 索引和有限查询结果 | 用一个无结构巨型 Dictionary 表示整个领域 |
| 普通 Dictionary | JSON DTO、迁移边界、可扩展 payload | 核心公共业务接口 |
| Autoload | VS 原则上不用；未来最多一个真正应用级 App | 每个 Manager 一个 Singleton、全局 Event Bus |
| Signal | UI 输入；Application 已提交结果到 UI | 资金链、AI、事件和随机抽取的结算顺序 |

关系优先保存稳定 ID，避免 RefCounted 双向强引用环。

## 4.7 Content Data

- 第一方权威内容：typed `.tres` Custom Resource。
- 存档与 Debug Snapshot：版本化 JSON。
- 本地化：CSV。
- 首版不用 SQLite、数据库插件或完整 Mod importer。
- 所有 Definition 有稳定 `id`，关系只存 ID，显示文字使用 localization key。
- Resource 加载后视为不可变；Runtime State 不得使用可变 Resource。
- 业务逻辑不得按显示名称分支，不得硬编码真实公司、现实 Benchmark 或高管。
- 未来外部内容包必须先转换/验证为同一 Definition 接口，Simulation 不感知来源文件格式。

## 4.8 Save Schema（从 G3 实现）

M0–M2 不提前实现完整存档，但后续必须遵守：

- Snapshot 是恢复权威来源；Replay Log 只用于调试。
- 保存 schema、游戏规则、Godot、内容包和摘要版本。
- 保存 tick/calendar、master seed、命名 RNG state、公司/市场/项目/合同、命令、到期效果、事件冷却和 AI 状态。
- 不保存 Node、Resource、Callable、Signal、对象实例 ID。
- 写临时文件 → flush/close → 回读校验 → 备份旧文件 → 替换。
- 加载到新对象图，迁移并验证不变量后才替换活动 GameSession。
- 迁移采用 `v1 → v2 → v3` 单步纯 DTO 链，并保留历史 fixture。
- 损坏、摘要错误或未来版本存档必须安全拒绝，不覆盖原文件。

## 4.9 UI 信息合同

- 固定 Game Shell + 页面切换 + Report/News Drawer，不采用地图中心结构。
- Vertical Slice 的核心页面：Command Center、Model Lab、Markets、Rivals、Finance、News/Events、Save/Load、开发版 Debug。
- 顶部始终显示的核心量不超过约 6 个；详细原因按需展开。
- 每个重大变化展示：前值、后值、前三项贡献、已知随机项、对手影响、Forecast、Go to source。
- 高频路径最多 1–2 层点击。
- 已知策略仍需重复多个相同点击时，操作必须批处理、委派或删除。
- 新 UI 使用 Anchor 和 Container，至少验证 1280×720 与 1920×1080；不得继续扩张绝对 offset。
- 模型发布必须是视觉/音效/报告上的高潮，而不是进度条静默结束。

## 4.10 AI Decision System

从 G2 起采用：

~~~text
合法性规则过滤
→ 人格/战略目标设置权重
→ Utility 评分
→ 小幅 Seeded noise 打破机械平局
→ 稳定 tie-breaker
→ 输出 Command + top reason_key
~~~

- AI 和玩家提交同类型 Command，经过相同合法性检查。
- AI 只读取可观察快照和自己的私有状态。
- AI 不能获得隐藏现金、未公开项目选择或玩家本季 Command。
- 重大行动应有预警；结果页展示对手行动和主要原因。
- 不使用 LLM、GOAP 黑箱或脚本作弊直接改 State。

## 4.11 Event System

Event Definition 后续至少包含：

~~~text
id
localization keys
trigger conditions
weight
prerequisites
choices
immediate effects
scheduled effects
AI reactions
cooldown
max occurrences
tags
~~~

Event 只能暴露/放大已有系统中的机会和风险，不能替代 Simulation。即使关闭所有随机 Event，训练、发布、容量、市场和对手反应闭环仍必须可玩。

---

# 5. 推荐目录与文件职责

以下是目标结构，不是 M0 的创建清单。Codex 只能按当前 Task Packet 增量创建实际需要的目录和文件，禁止一次性创建空目录、空 Manager 或占位脚本。

~~~text
res://
├── project.godot
├── main.tscn                         # Composition Root
├── bootstrap/                        # G1+
│   └── game_root.gd
├── application/                      # G1+
│   ├── game_session.gd               # UI 唯一业务入口
│   ├── commands/
│   │   ├── game_command.gd
│   │   └── command_result.gd
│   └── view_models/
├── simulation/                       # G1+
│   ├── engine/
│   │   ├── simulation_engine.gd      # 模拟门面
│   │   ├── simulation_clock.gd
│   │   └── tick_result.gd
│   ├── state/
│   │   ├── game_state.gd
│   │   ├── company_state.gd
│   │   ├── market_state.gd           # G2+
│   │   └── project_state.gd
│   ├── systems/
│   │   ├── finance_system.gd
│   │   ├── project_system.gd
│   │   ├── compute_system.gd         # G2+
│   │   ├── market_system.gd          # G2+
│   │   ├── ai_system.gd              # G2+
│   │   └── event_system.gd           # G3+
│   ├── ai/                            # G2+
│   ├── events/
│   │   ├── domain_event.gd
│   │   └── effect_contribution.gd
│   ├── rng/
│   └── rules/
│       ├── fixed_point.gd
│       └── state_invariants.gd
├── content/                           # G1/G2+
│   ├── definitions/
│   ├── packs/base/
│   │   └── content_pack_manifest.tres
│   ├── content_registry.gd
│   └── content_validator.gd
├── persistence/                       # G3+
│   ├── save_repository.gd
│   ├── save_codec.gd
│   ├── save_schema.gd
│   ├── snapshot_mapper.gd
│   └── migrations/
├── ui/                                # G1/G3+
│   ├── screens/
│   ├── components/
│   ├── presenters/
│   └── themes/
├── localization/                      # G3+
├── assets/
├── debug/                             # G2/G3+
├── tests/
│   ├── run_tests.gd                   # M0 创建
│   ├── run_tests.gd.uid               # Godot 生成时必须跟踪，禁止手写
│   ├── unit/
│   ├── integration/
│   ├── scene/
│   ├── determinism/
│   └── fixtures/
├── docs/
│   ├── .gdignore
│   ├── CODEX_HANDOFF_V0_1.md
│   ├── decisions/                     # 有真实 ADR 时再创建
│   └── task_packets/                  # TP-000 后按需创建
└── README.md                           # M0 创建
~~~

关键入口：

- `main.tscn`：Composition Root；最终只装配模块和 Game Shell。
- `application/game_session.gd`：UI 唯一业务用例入口。
- `simulation/engine/simulation_engine.gd`：纯模拟门面。
- `content/packs/base/content_pack_manifest.tres`：第一方内容入口。
- `tests/run_tests.gd`：显式登记/加载测试并以进程退出码报告结果。

依赖规则：

- `simulation/` 不依赖 `ui/`、`persistence/`、SceneTree 或资产。
- `ui/` 只能通过 `application/` 提交 Command 和读取 View Model。
- `content/definitions` 定义 Schema，`content/packs` 才保存具体内容。
- `persistence/snapshot_mapper.gd` 只在边界映射 typed State/DTO；其他 Persistence 模块保持 DTO-only。
- `assets/` 不包含业务数值。
- `tests/` 可依赖生产代码；生产代码绝不依赖测试。
- 不创建笼统 `scripts/`、`managers/` 或 `utils.gd` 垃圾桶。

---

# 6. Coding Standards

1. 只使用 Godot 4.7.1 普通 GDScript；不引入 C#/.NET、GDExtension 或未经批准的插件。
2. 遵守现有 UTF-8、LF 和 tab 缩进配置。
3. 文件、变量、函数和 signal 使用 `snake_case`；类型使用 `PascalCase`；场景节点使用有意义的英文 `PascalCase` 名称。
4. 参数、返回值、成员变量、signal 参数和容器元素在 Godot 支持时使用显式类型。
5. 核心公共 API 不用无结构 Dictionary 替代 typed Command、Result、State 或 Definition。
6. 每个文件保持单一职责；不得建立笼统 Manager/Utils。
7. 公共类型和非显而易见的公共方法使用 `##` 文档注释，说明单位、契约、失败结果和副作用；注释解释“为什么”。
8. UI callback 只能创建 Command、调用 Application 和刷新表现；禁止直接增减现金、份额、项目进度或调用随机。
9. 新 UI 使用 Anchor/Container；M0 只记录现有 absolute offset 技术债，不顺手重排。
10. Simulation 禁止 Node、SceneTree、文件 IO、系统时间、帧 delta、全局随机、Autoload 和 UI 类型。
11. 公式使用明确单位的 integer/fixed-point；除法、舍入和 clamp 必须显式。
12. Dictionary/ID 集合参与结算前按稳定 ID 排序；并列评分有稳定 tie-breaker。
13. 不使用引擎 hash、instance ID、文件枚举顺序或对象地址形成持久身份。
14. Content Definition 与 Runtime State 分离；共享 `.tres` 运行时不可修改。
15. 避免 RefCounted 强引用环；关系优先存稳定 ID。
16. 用户输入、存档和合法业务失败返回 typed error/result；`assert` 只用于测试或内部不变量。
17. DomainEvent/EffectContribution 必须来自实际计算，UI 不重算解释。
18. AI 生成玩家同类型 Command 并通过同一合法性检查，同时返回主要原因。
19. 每个核心系统至少测试正常、边界、非法输入和确定性；失败使 runner `quit(1)`。
20. 不硬编码真实公司、高管、商标、Logo、现实 Benchmark 或现实负面事件。
21. 不增加第三方测试框架、联网、遥测、Live LLM、SQLite 或新 renderer，除非用户另行批准。
22. 只修改当前 Task Packet 的 Files Allowed to Modify/Create；额外重构写成后续任务。
23. 场景文本改动后必须做 import、parse 和 scene smoke；不能只看 diff。
24. 每次任务结束时项目必须可打开、可运行、可回退，并报告完整 diff、命令、退出码和已知问题。
25. 不把可由 Codex 直接完成的文件编辑、节点创建或 Signal 连接推给用户；用户只负责产品选择和真正的视觉/试玩判断。
26. Godot 为 tracked `.gd` 生成对应 `.gd.uid` 时，该 UID 文件必须一同版本控制；不得手工编造 UID，也不得把正确生成的 UID 当作临时文件删除。

---

# 7. 门控实施计划与 First Codex Milestone

## 7.1 为什么采用 Gate，而不是一份巨型开发 Prompt

长期设计已经明确，但核心趣味仍有待验证。最优 Codex 工作方式是：

~~~text
一个权威产品/架构契约
→ 一个当前授权 Task Packet
→ 自动证据
→ 用户试玩/判断
→ Gate 决策
→ 再生成下一个窄 Task Packet
~~~

不得把完整路线一次交给 Codex 后让其连续实现。这样可以避免：

- 在趣味假设失败前积累大量架构和内容；
- 多个系统同时修改导致无法定位回归；
- UI、Simulation 和 Content 边界被临时写法侵蚀；
- 阶段 A 的未来愿景被误读为当前范围。

## 7.2 Gate 路线

| Gate | 阶段 | 核心交付 | 自动门槛 | 用户门槛 | 失败时 |
|---|---|---|---|---|---|
| G0 | M0 安全基线 | Git 原始恢复点、README、runner、scene smoke | 全部基线命令可重复、退出码可信、生产文件无变化 | 当前按钮与画面无回归 | 停止，不进入游戏重构 |
| G1 | M1 核心回合 | 纯 Game State、3 月 Tick、Cash/Revenue/Cost、一个项目、Effect 明细、最小 UI | 同输入结果一致；12 月时钟正确；UI 不改 State | 能看到一个决定造成可解释季度差异 | 边界不成立则重做，不加市场 |
| G2 | M2 经济战争 Prototype | 6 季度、训练/推理容量、两个市场、1 对手、5–6 行动、报告 | 100 局无非法状态；份额 10000 bps；固定 seed 一致 | 至少两种合理策略，有经济战争感 | 单一最优或容量无痛则重做 |
| G3 | M3 Vertical Slice | 8 季度、2 对手、开放/闭源、事件、News、Save、接近最终 UI | Save round-trip/resume；全 scene load；1200 月基线 | 30–45 分钟有高潮，愿意再玩且能解释失败 | 不加美术/事件数量，先修循环 |
| G4 | MVP | 24 季度、3 市场、4 对手、教程、40–60 事件、迁移 | 回归/迁移/性能稳定；无主导套路信号 | 目标玩家多数可独立完成，中后期不重复 | 不进入 EA，先修教程/路线 |
| G5 | 1.0 | 32 季度、4 路线、最多 6 对手、80–120 事件、音画/本地化/发行 QA | 全支持配置、存档兼容、无 P0/P1 | 新手能学、老玩家高效、商店承诺完整 | 不以内容数量掩盖质量门 |

数量是上限和验收锚点，不是必须填满的配额。

~~~mermaid
flowchart LR
    G0[Git and Test Baseline] --> G1[Explainable Core Quarter]
    G1 --> G2[6-Quarter Economic Prototype]
    G2 --> G3[8-Quarter Vertical Slice]
    G3 --> G4[Replayable MVP]
    G4 --> G5[Version 1.0 Production]
~~~

## 7.3 未来 Task Packet 顺序

以下只用于规划，不构成当前授权：

| 建议 ID | 内容 | 何时生成精确文件级规格 |
|---|---|---|
| TP-010 | Simulation Clock、Game State、Command/Result 骨架 | G0 通过后 |
| TP-011 | Finance + Project + EffectContribution | TP-010 通过后 |
| TP-012 | GameSession 与最小 Dashboard 接入 | TP-011 通过后 |
| TP-020 | 训练/推理 Compute Capacity | G1 通过后 |
| TP-021 | Consumer 与 Developer/API 市场 | TP-020 通过后 |
| TP-022 | 一个可解释 Utility 对手 | TP-021 通过后 |
| TP-023 | 6 季度 Prototype、报告与批量仿真 | TP-022 通过后 |
| TP-030+ | Vertical Slice UI、事件、开放策略、存档 | G2 试玩通过后 |

每个任务完成后只建议下一项。不得在当前任务中预建后续空文件。

## 7.4 Task Packet 必备字段

每个后续任务必须包含：

~~~text
Title / ID / Gate
Goal
Repository Facts
Player-visible Outcome
Files to Inspect
Files Allowed to Create
Files Allowed to Modify
Architecture Boundary
Implementation Steps
Acceptance Criteria
Automated Validation
Manual Validation
Non-goals
Stop Condition
Required Completion Report
~~~

## 7.5 当前唯一授权 Task：TP-000

### TP-000 — Git Safety Baseline and Headless Test Entry

**Gate：**G0 / M0
**授权范围：**只建立安全与验证基线。
**玩家可见结果：**现有 `START GAME → NEXT QUARTER → 日期推进` 行为保持不变；不新增玩法。
**用户/开发者结果：**项目有本地恢复点和可重复、可判定退出码的验证入口。

### Task TP-000.1 — 原始 Git 恢复点

**Goal**

在修改任何现有项目文件或创建测试代码前，让 `D:/ai_company_war/game` 具有可验证、可回退的原始提交。

**Files to Inspect**

~~~text
D:/ai_company_war/game/.editorconfig
D:/ai_company_war/game/.gitattributes
D:/ai_company_war/game/.gitignore
D:/ai_company_war/game/project.godot
D:/ai_company_war/game/main.tscn
D:/ai_company_war/game/main.gd
D:/ai_company_war/game/main.gd.uid
D:/ai_company_war/game/icon.svg
D:/ai_company_war/game/icon.svg.import
D:/ai_company_war/game/docs/.gdignore
D:/ai_company_war/game/docs/CODEX_HANDOFF_V0_1.md
D:/ai_company_war/Godot_v4.7.1-stable_win64.exe
D:/ai_company_war/Godot_v4.7.1-stable_win64_console.exe
~~~

还必须重新列出 `game` 全部文件，并检查当前目录及所有父目录的 Git 根。

**Files to Create**

- `D:/ai_company_war/game/.git/`，只能由 `git init` 创建。

**Files to Modify**

- 无。

**Implementation Steps**

1. 确认项目根精确为 `D:/ai_company_war/game`。
2. 检查实际文件、Hash 差异、renderer 和 main scene，并执行第 8.9 节命令集 A；此时只允许文件读取、Hash 与 `--version`，不得运行 import/scene。
3. 确认 `.gitignore` 已忽略 `.godot/`；不得把工作区外的 Godot 可执行文件加入仓库。
4. 执行 `git init -b main`，Git 根只能是 `game`。
5. 使用明确路径暂存已核对文件，不盲目执行 `git add -A`。
6. 审查 `git status`、`git ls-files`、`git diff --cached --check` 和 staged 文件列表。
7. 创建原始基线提交，建议消息：`chore: establish Godot project baseline`。
8. 如果 Git 身份未配置，停止并报告；不得自行修改全局 `user.name` 或 `user.email`。
9. initial commit 存在后，执行第 8.9 节命令集 B（import、现有脚本解析、scene/main smoke）。
10. 若命令集 B 失败或产生 tracked file 变化，保留 initial commit 和现场，停止并报告；不得删除生成文件或继续 TP-000.2。
11. initial commit 与命令集 B 都通过后，才进入 TP-000.2。

**Acceptance Criteria**

- `D:/ai_company_war/game` 成为独立 Git 仓库。
- 外层 `D:/ai_company_war` 不成为 Git 仓库。
- 存在一个准确记录阶段 B 后、实施前原貌的初始 commit。
- `.godot/`、引擎可执行文件、日志、导出物和临时文件未被跟踪。
- commit 后 `git status --porcelain` 为空。
- `project.godot`、`main.tscn`、`main.gd` 没有被改写。
- initial commit 后的命令集 B 全部通过，且没有产生未解释的 tracked file 变化。

**Automated Validation**

~~~powershell
$aiWarProject = 'D:/ai_company_war/game'

git -C $aiWarProject status --short --branch
git -C $aiWarProject ls-files
git -C $aiWarProject diff --cached --check
git -C $aiWarProject log -1 --oneline
~~~

**Manual Validation**

审查 initial commit 文件清单，确认没有 `.godot/`、本地引擎、未知文件或工作区外内容。

**Non-goals**

- 不创建测试代码或 README。
- 不修改任何已存在文件。
- 不重构 UI。
- 不实现 Simulation、经济、市场、AI、事件或存档。
- 不设置 remote，不 push。

**Stop Condition**

- 项目根、Godot 版本或 renderer 不一致；
- 出现来源不明的修改且无法确认归属；
- 已有意外的父级或嵌套 Git 仓库；
- 基线 Godot 命令失败；
- `.godot/` 将被跟踪；
- Git 初始化、staged diff 检查或 commit 失败；
- Git 身份缺失；
- initial commit 后的命令集 B 失败或修改 tracked file；
- 需要删除、移动或覆盖文件才能建立恢复点。

### Task TP-000.2 — 最小 Headless Runner

**Goal**

建立无需第三方插件、能以退出码明确表示成功/失败的最小测试 runner，并记录准确的项目启动方式。

**Files to Inspect**

- TP-000.1 的全部基线文件。

**Files to Create**

~~~text
D:/ai_company_war/game/README.md
D:/ai_company_war/game/tests/run_tests.gd
D:/ai_company_war/game/tests/run_tests.gd.uid  # 仅当 Godot 自动生成；必须跟踪
~~~

Codex 只直接创建前两个文本文件。`run_tests.gd.uid` 必须由 Godot 生成；不得手写、猜测或复制 UID。

**Files to Modify**

- 无。尤其不得修改 `project.godot`、`main.gd` 或 `main.tscn`。

**Runner Required Behavior**

`tests/run_tests.gd` 应继承 `SceneTree`，至少：

1. 显式加载 `res://main.tscn`；
2. 实例化并加入测试 SceneTree；
3. 验证根节点是 `Control`；
4. 验证 `TitleLabel`、`DateLabel`、`StartButton` 存在；
5. 验证初始标题、日期和按钮文字；
6. 通过按钮 `pressed` 信号验证第一次点击只改变按钮文字；
7. 再次触发并验证日期从 `2026 Q1` 进入 `2026 Q2`；
8. 输出逐项 `[PASS]` / `[FAIL]` 和最终汇总；
9. 任一失败 `quit(1)`，全部通过 `quit(0)`；
10. 支持 `--self-test-failure` 用户参数，使 runner 故障自检稳定返回 1。

测试当前草图的 NodePath 是有意的 smoke 基线。未来 UI 重构任务必须同时更新对应 smoke，不得为了保住旧 NodePath 阻止获准架构迁移。

`README.md` 至少记录：

- 项目定位的一句话；
- 项目根、Godot 精确版本、GDScript 和 GL Compatibility；
- 当前主场景；
- 本文件权威路径；
- 第 8 节的运行、解析、runner 和 scene smoke 命令；
- 当前 Gate 是 G0；
- 未来功能不得绕过 handoff 和 Task Packet。

**Implementation Steps**

1. 只直接创建 `README.md` 与 `tests/run_tests.gd`。
2. 实现 runner 正常和故障自检路径。
3. 执行第 8.9 节命令集 C；允许 Godot 自动生成 `tests/run_tests.gd.uid`。
4. 检查控制台错误文字和退出码。
5. 比较三个生产文件的 Hash 与 TP-000.1 基线。
6. 若 `tests/run_tests.gd.uid` 已生成，确认它与脚本一起进入 diff；不得删除。
7. 审查 diff，确保除 README、runner 和其 Godot 生成 UID 外没有其他文件变化。

**Acceptance Criteria**

- runner parse 返回 0。
- runner 正常路径返回 0。
- `--self-test-failure` 返回 1。
- runner 实际加载/实例化主场景并验证现有按钮行为。
- README 不包含虚构的导出、Steam、CI 或测试命令。
- `project.godot`、`main.tscn`、`main.gd` Hash 与 initial commit 一致。
- Godot 若生成 `tests/run_tests.gd.uid`，该文件保留并列入 M0 commit。
- 没有第三方插件或 Autoload。

**Automated Validation**

执行第 8.9 节命令集 C，并运行：

~~~powershell
git -C 'D:/ai_company_war/game' diff --check
git -C 'D:/ai_company_war/game' status --short
~~~

**Manual Validation**

阅读 runner 输出，确认故障不是只打印红字，而是真正返回 exit code 1。

**Non-goals**

- 不建立完整测试框架。
- 不实现任何生产 Simulation/Application/Content/Persistence 代码。
- 不更换 renderer。
- 不整理现有 UI 或改变按钮行为。
- 不测试尚不存在的经济、AI、事件和 Save。

**Stop Condition**

- 必须修改生产逻辑才能让 runner 通过；
- runner 挂起或退出码不可靠；
- parse/import/scene smoke 失败；
- 需要第三方插件；
- diff 包含 README、runner、其自动生成 UID 之外的未批准文件；
- 生产文件 Hash 改变。

### Task TP-000.3 — 验证与 M0 Commit

**Goal**

证明新增 README/test 入口后，项目仍可导入、解析、加载和运行，并将 M0 保存为独立本地 commit。

**Files to Inspect**

- 全部 Git diff；
- 全部验证输出；
- `README.md`；
- `tests/run_tests.gd`；
- `tests/run_tests.gd.uid`（若 Godot 已生成）。

**Files Allowed to Be Generated**

- `tests/run_tests.gd.uid`：仅当之前尚未生成时可由 Godot 创建；必须纳入检查和提交。
- Godot 还可更新被忽略的 `.godot/` 缓存。

**Implementation Steps**

1. 按第 8.9 节命令集 C 的精确顺序重跑完整自动验证；第 8.2 节交互命令不属于自动集合。
2. 检查退出码以及 `Parse Error`、`SCRIPT ERROR`、`ERROR:` 等引擎错误。
3. 检查 Git 没有出现意外 tracked file 变化。
4. 审查 `git diff --check` 和完整 diff。
5. 显式暂存 `README.md`、`tests/run_tests.gd`，以及 Godot 已生成的 `tests/run_tests.gd.uid`。
6. 再次审查 staged diff。
7. 创建本地 commit：`test: add Godot headless baseline validation`。
8. 确认工作树干净；不设置 remote，不 push。
9. 按第 12 节报告，并给用户手动启动步骤。
10. 停止；不得在同一任务开始 TP-010/M1。

**Acceptance Criteria**

- 全部自动检查通过。
- initial baseline commit 和 M0 test commit 均存在。
- M0 commit 后工作区干净。
- 当前 UI/游戏脚本/项目配置未改变。
- Godot 生成的 runner UID 已与 runner 一起提交，工作树没有遗留正确但未跟踪的 UID。
- 用户按步骤运行时应看到原有标题、日期和按钮行为。
- M1 尚未开始。

**Automated Validation**

~~~powershell
git -C 'D:/ai_company_war/game' diff --check
git -C 'D:/ai_company_war/game' status --short --branch
git -C 'D:/ai_company_war/game' log -2 --oneline
~~~

**Manual Validation**

1. 用 Godot 打开 `D:/ai_company_war/game/project.godot`。
2. 运行主场景。
3. 确认标题 `AI COMPANY WAR`、日期 `2026 Q1`、按钮 `START GAME`。
4. 第一次点击后按钮变为 `NEXT QUARTER`，日期仍为 Q1。
5. 第二次点击后日期变为 `2026 Q2`。
6. 确认无新增 UI、闪退或明显布局回归。

**Non-goals**

- 不实现 M1。
- 不增加现金、项目或新 UI。
- 不修复 absolute offset。
- 不新增正式内容、美术、存档或导出配置。

**Stop Condition**

- 任一自动检查失败或输出未解释的引擎错误；
- Godot 意外改写 tracked file；
- 当前行为回归；
- diff 超出允许范围；
- M0 commit 无法创建；
- 工作区不能恢复到 initial commit。

---

# 8. Testing and Run Commands

以下以 Windows PowerShell 为准。变量名是任务专用变量，不得改用 `$HOME` 等系统变量。

## 8.1 固定路径和精确版本

~~~powershell
$aiWarGodotEditor = 'D:/ai_company_war/Godot_v4.7.1-stable_win64.exe'
$aiWarGodotConsole = 'D:/ai_company_war/Godot_v4.7.1-stable_win64_console.exe'
$aiWarProject = 'D:/ai_company_war/game'
$aiWarExpectedVersion = '4.7.1.stable.official.a13da4feb'

$aiWarActualVersion = (& $aiWarGodotConsole --version).Trim()
if ($LASTEXITCODE -ne 0 -or $aiWarActualVersion -ne $aiWarExpectedVersion) {
    throw "Unexpected Godot version: $aiWarActualVersion"
}
~~~

## 8.2 交互式编辑器/项目

打开编辑器：

~~~powershell
& $aiWarGodotEditor --editor --path $aiWarProject
~~~

直接运行主项目：

~~~powershell
& $aiWarGodotEditor --path $aiWarProject
~~~

这些交互命令不替代自动测试。

## 8.3 Headless import

~~~powershell
& $aiWarGodotConsole --headless --path $aiWarProject --import
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE"
}
~~~

`--import` 会更新被忽略的 `.godot/` 缓存；运行后仍须检查 Git 状态。

## 8.4 当前生产脚本解析

~~~powershell
& $aiWarGodotConsole --headless --path $aiWarProject --check-only --script res://main.gd
if ($LASTEXITCODE -ne 0) {
    throw "main.gd parse check failed with exit code $LASTEXITCODE"
}
~~~

`--check-only` 只解析指定脚本及其静态依赖，不代表自动扫描全项目。

## 8.5 Runner 创建后的解析与测试

~~~powershell
& $aiWarGodotConsole --headless --path $aiWarProject --check-only --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) {
    throw "Test runner parse check failed with exit code $LASTEXITCODE"
}

& $aiWarGodotConsole --headless --path $aiWarProject --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) {
    throw "Headless tests failed with exit code $LASTEXITCODE"
}
~~~

Runner 必须显式 preload/登记未来测试和生产脚本，不能假设 `--check-only` 会遍历目录。

## 8.6 Runner 故障自检

~~~powershell
& $aiWarGodotConsole --headless --path $aiWarProject --script res://tests/run_tests.gd -- --self-test-failure
if ($LASTEXITCODE -ne 1) {
    throw "Runner failure self-test should exit 1, actual: $LASTEXITCODE"
}
~~~

`--` 后的参数由 `OS.get_cmdline_user_args()` 读取。

## 8.7 主场景 smoke

~~~powershell
$aiWarSceneOutput = & $aiWarGodotConsole --headless --path $aiWarProject --scene res://main.tscn --quit-after 3 2>&1
$aiWarSceneExitCode = $LASTEXITCODE
$aiWarSceneOutput | ForEach-Object { Write-Output $_ }
$aiWarSceneText = $aiWarSceneOutput -join "`n"

if (
    $aiWarSceneExitCode -ne 0 -or
    $aiWarSceneText -match 'Parse Error|SCRIPT ERROR|ERROR:'
) {
    throw "Main scene smoke failed with exit code $aiWarSceneExitCode"
}
~~~

`--quit-after 3` 表示 3 次主循环迭代，不是 3 秒。

## 8.8 当前主项目 smoke

~~~powershell
& $aiWarGodotConsole --headless --path $aiWarProject --quit-after 2
if ($LASTEXITCODE -ne 0) {
    throw "Main project smoke failed with exit code $LASTEXITCODE"
}
~~~

## 8.9 TP-000 精确命令集合

“执行命令集”只表示下列明确顺序，不能解释为运行整个第 8 节：

| 集合 | 执行时机 | 精确内容 |
|---|---|---|
| A | initial commit 之前 | 文件清单、三个核心文件 SHA-256、renderer/main scene 文本核对，以及 8.1 `--version`；全部为只读，不运行 Godot import/scene |
| B | initial commit 之后、runner 创建之前 | 依次执行 8.3、8.4、8.7、8.8；随后检查 tracked file 与 Hash |
| C | runner 创建后及 TP-000 最终验证 | 依次执行 8.3、8.4、8.5、8.6、8.7、8.8；随后检查 UID、Hash、`git diff --check` 和 Git status |

特别规则：

- 第 8.2 节只属于 Manual Validation。自动集合不得打开会等待用户关闭的编辑器或游戏窗口。
- 第 8.6 节进程返回 1 是故障自检的**预期通过结果**；只有不是 1 才失败。执行后继续验证时要记录该预期值，不能把它误报为整个 suite 失败。
- 集合 B/C 中任何非预期退出码或引擎错误都触发 Stop Condition。
- import 或 parse 若生成 `tests/run_tests.gd.uid`，保留并跟踪；不得手工生成或删除。

## 8.10 测试矩阵（按 Gate 增量实现）

| 测试 | G0 | G1 | G2 | G3+ |
|---|---:|---:|---:|---:|
| Import / main parse / scene smoke | 必须 | 必须 | 必须 | 必须 |
| Runner 正常与故障 exit code | 必须 | 必须 | 必须 | 必须 |
| Clock / Finance / Project unit | — | 必须 | 必须 | 必须 |
| Invariants / fixed seed digest | — | 必须 | 必须 | 必须 |
| Compute / Market / AI | — | — | 必须 | 必须 |
| 100-run soak | — | — | 必须 | 必须 |
| Content validation | — | 基础 | 必须 | 必须 |
| Save round-trip / resume / migration | — | — | — | 必须 |
| 1200-month performance baseline | — | — | — | 必须 |
| 1280×720 / 1920×1080 UI | 无回归 | 最小 | Prototype | 完整 |

首版不引入 GUT、GdUnit4 或其他第三方测试框架。只有自建 runner 已被实际证明不足、且用户另行批准时才评估。

## 8.11 失败报告

任何命令失败时停止当前写入并报告：

~~~text
Failed Command
Exit Code
Relevant Console Output
Expected Result
Actual Result
Tracked Files Changed
Untracked Files Created
Whether the Baseline Commit Can Restore the Project
Suggested Narrow Next Step
~~~

不得只说“测试失败”或“应该是环境问题”。也不得只看 exit code；scene smoke 还要检查引擎错误输出。

---

# 9. Git Safety Workflow

## 9.1 首次建库授权

用户已批准 TP-000 在 `D:/ai_company_war/game` 初始化本地 Git 并建立 baseline commit。授权不包括：

- 在外层 `D:/ai_company_war` 初始化 Git；
- 添加 remote；
- push；
- 修改全局 Git 配置；
- 删除、清理或重置用户文件；
- 提交工作区外的 Godot 可执行文件。

## 9.2 固定顺序

1. 查找父级/当前目录 Git 根；
2. 清点所有文件、Hash、renderer/main scene 和忽略规则，只运行 `--version`；
3. 确认 `.godot/` 被忽略；
4. `git init -b main`；
5. 显式暂存核对过的路径；
6. 审查 staged file list 和 `git diff --cached --check`；
7. 创建 initial baseline commit；
8. initial commit 存在后才运行 import、parse 和 scene/main smoke；
9. 只修改当前 Task 允许文件；
10. 跑 runner 正常/预期失败、import、parse、scene smoke，并审查 UID、Hash 和 diff；
11. 创建当前 Task 的本地 commit；
12. 报告 `git status --short --branch`、diff、commit 和测试证据。

## 9.3 强制安全规则

- 不使用 `git reset --hard`、`git clean -fd`、`git checkout --` 或等价破坏命令。
- 不覆盖、移动或删除来源不明的文件。
- 不将 `.godot/`、导出 build、日志、临时存档、本机设置或引擎 exe 加入 Git。
- Godot 为 tracked `.gd` 生成的 `.gd.uid` 不是临时缓存；必须与脚本一起审查和提交。
- 初次暂存不使用无审查的 `git add -A`。
- 缺少 Git identity 时停止；不得擅自设置 global identity。
- 发现已有用户 commit、branch、remote 或未提交修改时，保留并重新规划，不重写历史。
- 每个 commit 前后运行最窄相关验证和 `git diff --check`。
- 当前任务只创建本地 commit，不 push。
- 用户最新任务若明确要求不 commit，则保留 diff 并报告；最新用户指令优先。

---

# 10. Definition of Done（完成定义）

任何任务只有同时满足以下条件才算完成：

- [ ] 实际仓库状态已在任务开始时核对；
- [ ] Godot 项目可正常打开；
- [ ] 无目标脚本解析错误；
- [ ] 指定场景可加载并运行；
- [ ] 功能达到当前 Task 的 Acceptance Criteria；
- [ ] 指定自动测试全部通过，命令与退出码已记录；
- [ ] 用户能看到或验证明确的任务结果；
- [ ] 所有修改文件及用途已报告；
- [ ] 完整 diff 已审查，无越界文件；
- [ ] 已知问题和未验证项已列出；
- [ ] Non-goals 未被突破；
- [ ] 工作区可继续开发且有恢复点；
- [ ] 下一 Gate 没有被自动开始。

M0 特别说明：

> M0 的新增结果是 Git 恢复点、README、测试入口和可重复验证证据；玩家画面应保持不变。M0 不以新增经济玩法作为完成条件，也不得为了满足“玩家可见新增结果”擅自进入 M1。

---

# 11. Explicit Non-goals 与防跑偏护栏

## 11.1 TP-000 特有 Non-goals

- 不修改 `project.godot`、`main.gd`、`main.tscn` 或 icon。
- 不重构现有季度逻辑。
- 不实现 Game State、Simulation Tick、Finance、Project、RNG、市场、AI、事件或 Save。
- 不创建 `application/`、`simulation/`、`content/`、`persistence/` 的空脚手架。
- 不修改 renderer。
- 不增加按钮、Label、页面、Debug Panel 或正式 UI。
- 不修复 absolute offset。
- 不安装第三方测试插件。
- 不移动现有文件。
- 不创建 export preset、Steam 集成、CI 或 remote。
- 不开始 M1。

## 11.2 Prototype / Vertical Slice 不做

- 全球地图、国家实体、领土、外交、战争；
- Enterprise 完整市场（推迟到 MVP）；
- 完整芯片供应链、电力网或数据中心建设；
- 逐员工、办公室、家具、座位、餐饮、停车；
- 逐服务器、逐机架、逐芯片 SKU、逐 Token 模拟；
- 完整融资树、股票、IPO、敌意收购、子公司；
- 真实公司、Logo、高管、现实 Benchmark；
- 多人、联网排行榜、实时新闻、Live LLM、遥测；
- 牌库、手牌、抽牌、弃牌、稀有度、卡包、构筑；
- 数百事件；
- 正式商业美术；
- 完整 Mod SDK / Workshop；
- 大型 3D/2.5D 世界。

## 11.3 即使 1.0 也不自动承诺

- 全球可导航地图；
- 多人；
- 3D 办公室；
- 逐机架/逐 Token 模拟；
- 完整股票市场和集团子公司；
- 完整 Mod SDK；
- 现实公司内容；
- Live AI 服务。

## 11.4 防止做成 Startup Company

> Research、Systems、Product/GTM 人才直接作为团队容量分配到项目和运营。Compute 是可分配容量，不是玩家逐台摆放的服务器物品。研发是长期项目状态机，不是组件 Crafting Loop。

禁止：

- Backend/UI/Research Component 等中间库存；
- 员工循环生产研发材料；
- 单个员工逐日行程；
- 重复招聘、排班、扩容点击成为中后期主要玩法；
- 对手只作为排行榜数字。

验收：

> 如果玩家已经知道正确策略，却仍需连续执行多个相同机械点击才能生效，该实现不合格。

## 11.5 防止做成全球大战略

> “产业网络”是公司、市场、容量供应、渠道、资本和政策环境之间的关系数据，不是一张可占领的地理地图。玩家始终是公司 CEO。

外部环境先只通过两个市场、Frontier Clock、容量修正、政策环境、新闻、事件、合同和对手行动进入。

验收：

> 删除全部地理坐标后，核心季度循环必须完整成立。需要移动镜头、占领区域或管理国家实体才有趣的提案不属于当前产品。

## 11.6 防止做成纯卡牌

> 本文件中的 Card 只表示 UI 信息容器、Event 呈现或外部规则状态，不表示可收集/构筑卡牌。

不存在牌库、手牌、抽牌、弃牌、稀有度、卡包或随机发行动卡。可用行动来自稳定 Action Definition 和当前 Game State；Event 来自实际状态、条件和风险。

验收：

> 关闭随机 Event 与 Card 表现后，训练、发布、推理容量、市场份额和对手反应仍必须可玩，否则内容正在替代系统。

## 11.7 最终产品偏航测试

> 如果一个实现把玩家变成员工与服务器的微操主管、把外部环境变成需要占领的世界地图，或把季度决策变成抽牌和选卡，它已经偏离已批准产品；应停止并回到“CEO 分配稀缺容量 → 长期项目 → 共同市场与对手反应 → 可解释季度报告”的核心闭环。

---

# 12. Codex 完成任务后的汇报格式

Codex 必须原样使用以下八个英文标题，不得省略：

~~~text
Summary
Changed Files
Implemented Features
Validation Performed
Manual Test Steps
Known Issues
Recommended Next Task
Suggested Git Commit
~~~

最低内容要求：

## Summary

- 当前 Task/Gate 是否真正完成；
- 是否遇到 Stop Condition；
- 是否进入了下一 Gate（正确答案通常应为“否”）。

## Changed Files

- 每个绝对路径或 `res://` 路径；
- 新建/修改/删除状态；
- 修改原因；
- 明确列出本来禁止修改且确实未改的核心文件。

## Implemented Features

- 只列实际完成的内容；
- M0 必须明确“未新增游戏玩法”。

## Validation Performed

- 每条真实运行的命令；
- exit code；
- 关键输出；
- 自动与人工验证分开；
- 未运行的命令不得写成通过。

## Manual Test Steps

- 给用户最短、明确的 Godot 试玩步骤；
- 不要求用户复制代码、创建节点或连接 Signal。

## Known Issues

- 未验证项、平台限制、Git 状态、布局债务或任何警告；
- 没有则明确写 `None`。

## Recommended Next Task

- 只建议下一个窄任务；
- M0 后只能建议生成/审批 TP-010，不得在同一任务实施。

## Suggested Git Commit

- 已创建的 commit hash/message；
- 尚未提交时给出建议 message 和原因；
- 不暗示已经 push。

---

# 附录 A：后续 Codex Task Packet 模板

~~~text
# [TP-ID] Title

Gate
Authorization

## Goal
## Repository Facts
## Player-visible Outcome

## Files to Inspect
## Files Allowed to Create
## Files Allowed to Modify

## Architecture Boundary
## Implementation Steps

## Acceptance Criteria
## Automated Validation
## Manual Validation

## Non-goals
## Stop Condition

## Required Completion Report
~~~

Task Packet 写作规则：

- 一个包只验证一个主要风险；
- Files Allowed 必须使用精确路径；
- Acceptance Criteria 必须可观察或可机械判断；
- 自动验证必须给出可运行命令，不写“确保没有错误”；
- 手工验证只保留视觉、可读性、节奏和游戏感；
- Non-goals 必须列出最可能被顺手实现的相邻功能；
- Stop Condition 必须说明何时停下，而不是继续扩大修复；
- 每个包结束时项目可运行且有恢复点。

# 附录 B：下一 Gate 的生成规则

TP-000 完成后，不直接开始 M1。先基于实际 M0 仓库生成 `TP-010`，至少重新确认：

1. Git baseline 和 M0 commit；
2. runner 的真实接口；
3. 当前 main 场景/脚本；
4. Godot 4.7.1 解析行为；
5. 最小纯 `RefCounted` Game State/Clock 文件清单；
6. UI 保持可见季度按钮的迁移策略；
7. M1 只做 Cash/Revenue/Cost/Project/3-month tick/Effect 明细；
8. M1 不做 Compute Market、AI、Event 或 Save；
9. M1 自动测试与用户可见闭环；
10. M1 的独立 Stop Condition。

只有用户批准 TP-010 后才能实施。

---

**当前最终指令：执行时只做 TP-000，完成后停止并汇报；不要自动开始 M1。**
