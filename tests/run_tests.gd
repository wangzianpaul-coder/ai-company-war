extends SceneTree


const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const GAME_COMMAND_SCRIPT = preload("res://simulation/commands/game_command.gd")
const COMMAND_RESULT_SCRIPT = preload("res://simulation/commands/command_result.gd")
const SIMULATION_CLOCK_SCRIPT = preload("res://simulation/engine/simulation_clock.gd")
const GAME_STATE_SCRIPT = preload("res://simulation/state/game_state.gd")
const TEST_SIMULATION_CLOCK_SCRIPT = preload("res://tests/unit/test_simulation_clock.gd")

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	if OS.get_cmdline_user_args().has("--self-test-failure"):
		_check(false, "Runner failure self-test")
		_finish()
		return

	_check(GAME_COMMAND_SCRIPT != null, "GameCommand script is explicitly preloaded")
	_check(COMMAND_RESULT_SCRIPT != null, "CommandResult script is explicitly preloaded")
	_check(SIMULATION_CLOCK_SCRIPT != null, "SimulationClock script is explicitly preloaded")
	_check(GAME_STATE_SCRIPT != null, "GameState script is explicitly preloaded")
	_check(TEST_SIMULATION_CLOCK_SCRIPT != null, "Simulation clock unit suite is explicitly preloaded")
	TEST_SIMULATION_CLOCK_SCRIPT.run(Callable(self, "_check"))

	_check(MAIN_SCENE != null, "Main scene is explicitly preloaded")

	var main_instance: Node = MAIN_SCENE.instantiate()
	_check(main_instance != null, "Main scene instantiates")
	if main_instance == null:
		_finish()
		return

	_check(root != null, "SceneTree root exists")
	if root == null:
		main_instance.free()
		_finish()
		return

	root.add_child(main_instance)
	await process_frame

	_check(main_instance is Control, "Main scene root is Control")

	var title_label: Label = main_instance.get_node_or_null(^"TitleLabel") as Label
	var date_label: Label = main_instance.get_node_or_null(^"DateLabel") as Label
	var start_button: Button = main_instance.get_node_or_null(^"StartButton") as Button

	_check(title_label != null, "TitleLabel exists and is a Label")
	_check(date_label != null, "DateLabel exists and is a Label")
	_check(start_button != null, "StartButton exists and is a Button")
	_check(title_label != null and title_label.text == "AI COMPANY WAR", "Initial title is AI COMPANY WAR")
	_check(date_label != null and date_label.text == "2026 Q1", "Initial date is 2026 Q1")
	_check(start_button != null and start_button.text == "START GAME", "Initial button text is START GAME")

	if start_button != null:
		start_button.pressed.emit()
	await process_frame
	_check(start_button != null and start_button.text == "NEXT QUARTER", "First press changes button to NEXT QUARTER")
	_check(date_label != null and date_label.text == "2026 Q1", "First press keeps date at 2026 Q1")

	if start_button != null:
		start_button.pressed.emit()
	await process_frame
	_check(date_label != null and date_label.text == "2026 Q2", "Second press advances date to 2026 Q2")
	_check(start_button != null and start_button.text == "NEXT QUARTER", "Second press keeps button at NEXT QUARTER")

	main_instance.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % description)
	else:
		_fail_count += 1
		print("[FAIL] %s" % description)


func _finish() -> void:
	print("[SUMMARY] passed=%d failed=%d" % [_pass_count, _fail_count])
	quit(0 if _fail_count == 0 else 1)
