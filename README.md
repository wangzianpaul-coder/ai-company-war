# AI Company War

`AI Company War` 是一款面向 Windows PC / Steam 的单人离线、季度回合制 AI 产业经营策略游戏。

## 项目基线

- 项目根目录：`D:/ai_company_war/game`
- Godot：`4.7.1.stable.official.a13da4feb`（普通版本，不使用 .NET）
- 脚本语言：GDScript
- Renderer：GL Compatibility
- 主场景：`res://main.tscn`
- 权威实施说明：`D:/ai_company_war/game/docs/CODEX_HANDOFF_V0_1.md`
- 跨 thread 工作流：`D:/ai_company_war/game/AGENTS.md`
- 当前任务指针：`D:/ai_company_war/game/docs/CURRENT_TASK.md`
- 当前开发 Gate/Task：以实际仓库和 `D:/ai_company_war/game/docs/CURRENT_TASK.md` 为准

未来功能必须先经过权威 handoff 和获准 Task Packet，不得从路线图直接提前实施。

## Task Packet 工作流

- 一个 Codex thread 只执行一个 Task Packet。
- 每个新 thread 先读取 `AGENTS.md`、`docs/CURRENT_TASK.md` 和指向的 Task Packet。
- 当前 TP 完成并通过必要人工验收后，Codex 生成唯一后继 Task Packet；后继文件内含可复制的下一 thread prompt。
- 自动生成后继文件不等于授权或实施。用户手动把该 prompt 发到新 thread 才授权对应 TP。
- 每个真正完成的 TP 必须提交并普通 push 到已确认的 GitHub upstream，随后核实远端 SHA；禁止 force-push 或自动改写/合并远端历史。
- GitHub remote/upstream 的动态状态记录在 `docs/CURRENT_TASK.md`；每个 TP 开工前必须重新核验，缺失或分叉时停止。

## PowerShell 路径与版本检查

```powershell
$aiWarGodotEditor = 'D:/ai_company_war/Godot_v4.7.1-stable_win64.exe'
$aiWarGodotConsole = 'D:/ai_company_war/Godot_v4.7.1-stable_win64_console.exe'
$aiWarProject = 'D:/ai_company_war/game'
$aiWarExpectedVersion = '4.7.1.stable.official.a13da4feb'

$aiWarActualVersion = (& $aiWarGodotConsole --version).Trim()
if ($LASTEXITCODE -ne 0 -or $aiWarActualVersion -ne $aiWarExpectedVersion) {
    throw "Unexpected Godot version: $aiWarActualVersion"
}
```

## 手动打开与运行

打开编辑器：

```powershell
& $aiWarGodotEditor --editor --path $aiWarProject
```

直接运行主项目：

```powershell
& $aiWarGodotEditor --path $aiWarProject
```

这些交互命令不替代自动验证。

## Headless import 与脚本解析

```powershell
& $aiWarGodotConsole --headless --path $aiWarProject --import
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE"
}

& $aiWarGodotConsole --headless --path $aiWarProject --check-only --script res://main.gd
if ($LASTEXITCODE -ne 0) {
    throw "main.gd parse check failed with exit code $LASTEXITCODE"
}

& $aiWarGodotConsole --headless --path $aiWarProject --check-only --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) {
    throw "Test runner parse check failed with exit code $LASTEXITCODE"
}
```

## Headless runner

正常路径必须返回退出码 `0`：

```powershell
& $aiWarGodotConsole --headless --path $aiWarProject --script res://tests/run_tests.gd
if ($LASTEXITCODE -ne 0) {
    throw "Headless tests failed with exit code $LASTEXITCODE"
}
```

故障自检必须返回退出码 `1`；这里的 `1` 是预期通过结果：

```powershell
& $aiWarGodotConsole --headless --path $aiWarProject --script res://tests/run_tests.gd -- --self-test-failure
if ($LASTEXITCODE -ne 1) {
    throw "Runner failure self-test should exit 1, actual: $LASTEXITCODE"
}
```

## TP-023 六季度 batch-only 验证

开发者批量验证必须使用以下精确入口；它只运行固定的 100 局 batch contract，不运行普通 150 项 suite：

```powershell
$aiWarBatchOutput = @(& $aiWarGodotConsole --headless --path $aiWarProject --script res://tests/run_tests.gd -- --tp023-batch-only 2>&1)
$aiWarBatchExitCode = $LASTEXITCODE
$aiWarBatchOutput | ForEach-Object { Write-Output $_ }
$aiWarBatchText = $aiWarBatchOutput -join "`n"

if (
    $aiWarBatchExitCode -ne 0 -or
    $aiWarBatchText -notmatch '\[BATCH\] policies training_first=50 inference_first=50' -or
    $aiWarBatchText -notmatch '\[BATCH\] counts games=100 quarters=600 reports=600 failed=0' -or
    $aiWarBatchText -notmatch '\[BATCH\] commands start=100 set=600 advance=600' -or
    $aiWarBatchText -notmatch '\[BATCH\] streams events_unchanged_games=100 market_unchanged_games=100' -or
    $aiWarBatchText -notmatch '\[BATCH\] aggregate aggregate\|100\|600\|600\|0\|50\|50' -or
    $aiWarBatchText -notmatch '\[BATCH\] digest [0-9a-f]{64}' -or
    $aiWarBatchText -notmatch '\[BATCH\] errors none' -or
    $aiWarBatchText -match '\[SUMMARY\]'
) {
    throw "TP-023 batch-only validation failed with exit code $aiWarBatchExitCode"
}
```

成功输出还包含以 `acw-tp023-batch-v1` 开始的 702 条 canonical lines；完整文本使用 LF 和单一末尾 LF。同一固定 Godot/rule 版本下重复运行时，canonical lines、`aggregate|100|600|600|0|50|50` 和 64 位小写 SHA-256 digest 必须逐字一致。digest 仅是重现性证据，不替代状态、报告和 invariant 断言。

故障注入验证必须返回退出码 `1`，且不能被计为成功：

```powershell
& $aiWarGodotConsole --headless --path $aiWarProject --script res://tests/run_tests.gd -- --tp023-batch-only --tp023-inject-batch-failure
if ($LASTEXITCODE -ne 1) {
    throw "Injected TP-023 batch failure should exit 1, actual: $LASTEXITCODE"
}
```

## 场景与主项目 smoke

```powershell
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

& $aiWarGodotConsole --headless --path $aiWarProject --quit-after 2
if ($LASTEXITCODE -ne 0) {
    throw "Main project smoke failed with exit code $LASTEXITCODE"
}
```

项目目前没有获准的导出 preset、Steam 发布流程或 CI 命令。
