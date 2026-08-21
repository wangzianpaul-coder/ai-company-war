# AI Company War

`AI Company War` 是一款面向 Windows PC / Steam 的单人离线、季度回合制 AI 产业经营策略游戏。

## 项目基线

- 项目根目录：`D:/ai_company_war/game`
- Godot：`4.7.1.stable.official.a13da4feb`（普通版本，不使用 .NET）
- 脚本语言：GDScript
- Renderer：GL Compatibility
- 主场景：`res://main.tscn`
- 权威实施说明：`D:/ai_company_war/game/docs/CODEX_HANDOFF_V0_1.md`
- 当前开发 Gate：`G0 / M0`

未来功能必须先经过权威 handoff 和获准 Task Packet，不得从路线图直接提前实施。

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
