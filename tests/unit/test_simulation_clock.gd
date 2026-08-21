extends RefCounted


const GameCommandType = preload("res://simulation/commands/game_command.gd")
const CommandResultType = preload("res://simulation/commands/command_result.gd")
const SimulationClockType = preload("res://simulation/engine/simulation_clock.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807


static func run(report: Callable) -> void:
	_test_typed_boundaries(report)
	_test_default_clock(report)
	_test_one_month_advance(report)
	_test_three_explicit_month_advances(report)
	_test_year_rollover(report)
	_test_invalid_advance_is_atomic(report)
	_test_deterministic_sequences(report)


static func _test_typed_boundaries(report: Callable) -> void:
	var command: GameCommandType = GameCommandType.new()
	var success_result: CommandResultType = CommandResultType.new(true)
	var failure_result: CommandResultType = CommandResultType.new(false)
	var first_state: GameStateType = GameStateType.new()
	var second_state: GameStateType = GameStateType.new()
	var first_clock: SimulationClockType = first_state.get_clock()
	var second_clock: SimulationClockType = second_state.get_clock()

	_report(report, command is RefCounted, "GameCommand is a pure RefCounted boundary")
	_report(report, success_result is RefCounted and success_result.is_successful(), "CommandResult represents typed success")
	_report(report, not failure_result.is_successful(), "CommandResult represents typed failure without a payload")
	_report(report, first_clock is SimulationClockType, "GameState owns a typed SimulationClock")
	_report(report, first_clock != second_clock, "Separate GameState instances own separate clocks")


static func _test_default_clock(report: Callable) -> void:
	var clock: SimulationClockType = SimulationClockType.new()

	_report(report, clock is RefCounted, "SimulationClock is a pure RefCounted object")
	_report(report, clock.get_year() == 2026, "Default clock year is 2026")
	_report(report, clock.get_month() == 1, "Default clock month is January")
	_report(report, clock.get_quarter() == 1, "Default clock quarter is Q1")


static func _test_one_month_advance(report: Callable) -> void:
	var clock: SimulationClockType = SimulationClockType.new()
	var advanced: bool = clock.advance_month()

	_report(report, advanced, "One month advance succeeds")
	_report(report, clock.get_year() == 2026 and clock.get_month() == 2, "One month advances January to February 2026")
	_report(report, clock.get_quarter() == 1, "February remains in Q1")


static func _test_three_explicit_month_advances(report: Callable) -> void:
	var clock: SimulationClockType = SimulationClockType.new()
	var first_advance: bool = clock.advance_month()
	var second_advance: bool = clock.advance_month()
	var third_advance: bool = clock.advance_month()

	_report(report, first_advance and second_advance and third_advance, "Three explicit month advances succeed")
	_report(report, clock.get_year() == 2026 and clock.get_month() == 4, "Three months advance January to April 2026")
	_report(report, clock.get_quarter() == 2, "April is derived as Q2")


static func _test_year_rollover(report: Callable) -> void:
	var clock: SimulationClockType = SimulationClockType.new()
	var eleven_months_advanced: bool = clock.advance_months(11)

	_report(report, eleven_months_advanced, "Eleven month batch advance succeeds")
	_report(report, clock.get_year() == 2026 and clock.get_month() == 12 and clock.get_quarter() == 4, "Eleven months reach December 2026 Q4")

	var twelfth_month_advanced: bool = clock.advance_month()
	_report(report, twelfth_month_advanced, "Twelfth month advance succeeds")
	_report(report, clock.get_year() == 2027 and clock.get_month() == 1 and clock.get_quarter() == 1, "Twelve months roll over to January 2027 Q1")


static func _test_invalid_advance_is_atomic(report: Callable) -> void:
	var clock: SimulationClockType = SimulationClockType.new()
	var zero_advance: bool = clock.advance_months(0)

	_report(report, zero_advance, "Zero month advance is a valid no-op")
	_report(report, clock.get_year() == 2026 and clock.get_month() == 1 and clock.get_quarter() == 1, "Zero month advance leaves the clock unchanged")

	var negative_advance: bool = clock.advance_months(-1)
	_report(report, not negative_advance, "Negative month advance is rejected")
	_report(report, clock.get_year() == 2026 and clock.get_month() == 1 and clock.get_quarter() == 1, "Rejected negative advance is atomic")

	var initial_advance: bool = clock.advance_month()
	var before_year: int = clock.get_year()
	var before_month: int = clock.get_month()
	var before_quarter: int = clock.get_quarter()
	var overflow_advance: bool = clock.advance_months(MAX_SIGNED_INT)

	_report(report, initial_advance and not overflow_advance, "Overflowing month advance is rejected")
	_report(
		report,
		clock.get_year() == before_year and clock.get_month() == before_month and clock.get_quarter() == before_quarter,
		"Rejected overflow advance leaves no partial state"
	)


static func _test_deterministic_sequences(report: Callable) -> void:
	var first_clock: SimulationClockType = SimulationClockType.new()
	var second_clock: SimulationClockType = SimulationClockType.new()
	var sequence: Array[int] = [1, 2, 9, 12, 25]
	var results_match: bool = true

	for month_count in sequence:
		var first_result: bool = first_clock.advance_months(month_count)
		var second_result: bool = second_clock.advance_months(month_count)
		results_match = results_match and first_result == second_result
		results_match = results_match and first_clock.get_year() == second_clock.get_year()
		results_match = results_match and first_clock.get_month() == second_clock.get_month()
		results_match = results_match and first_clock.get_quarter() == second_clock.get_quarter()

	_report(report, results_match, "Equal clocks and month sequences remain deterministic")


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
