class_name GameSession
extends RefCounted


const GameCommandType = preload("res://simulation/commands/game_command.gd")
const CommandResultType = preload("res://simulation/commands/command_result.gd")
const StartProjectCommandType = preload("res://simulation/commands/start_project_command.gd")
const AdvanceQuarterCommandType = preload("res://simulation/commands/advance_quarter_command.gd")
const SimulationEngineType = preload("res://simulation/engine/simulation_engine.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")
const SimulationClockType = preload("res://simulation/engine/simulation_clock.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1

signal committed_result(view_model: DashboardViewModelType)

var _engine: SimulationEngineType = SimulationEngineType.new()
var _active_state: GameStateType
var _last_committed_contributions: Array[EffectContributionType] = []
var _current_view_model: DashboardViewModelType


## Takes ownership of an independent copy of the supplied initial state.
func _init(p_initial_state: GameStateType) -> void:
	if p_initial_state == null:
		_active_state = GameStateType.new()
	else:
		_active_state = p_initial_state.copy()
	var no_contributions: Array[EffectContributionType] = []
	_current_view_model = _build_view_model(_active_state, no_contributions)


## Accepts only the two concrete G1 commands and publishes only complete success.
func submit_command(command: GameCommandType) -> CommandResultType:
	if command == null:
		return CommandResultType.new(false)

	var tick_result: TickResultType
	if command.get_script() == StartProjectCommandType:
		tick_result = _engine.start_project(_active_state)
	elif command.get_script() == AdvanceQuarterCommandType:
		tick_result = _engine.advance_quarter(_active_state)
	else:
		return CommandResultType.new(false)

	if tick_result == null or not tick_result.is_successful():
		return CommandResultType.new(false)
	var candidate_state: GameStateType = tick_result.get_state_snapshot()
	if candidate_state == null:
		return CommandResultType.new(false)
	var candidate_contributions: Array[EffectContributionType] = tick_result.get_contributions()
	var candidate_view_model: DashboardViewModelType = _build_view_model(
		candidate_state,
		candidate_contributions
	)
	if candidate_view_model == null:
		return CommandResultType.new(false)

	_active_state = candidate_state
	_last_committed_contributions.clear()
	for contribution in candidate_contributions:
		_last_committed_contributions.append(contribution)
	_current_view_model = candidate_view_model
	committed_result.emit(_current_view_model)
	return CommandResultType.new(true)


## Returns an independent snapshot for tests and non-UI inspection.
func get_state_snapshot() -> GameStateType:
	return _active_state.copy()


## Returns a typed array copy preserving the committed source order.
func get_last_committed_contributions() -> Array[EffectContributionType]:
	var copied_contributions: Array[EffectContributionType] = []
	for contribution in _last_committed_contributions:
		copied_contributions.append(contribution)
	return copied_contributions


## Returns the current immutable-by-interface display values.
func get_current_view_model() -> DashboardViewModelType:
	return _current_view_model


func _build_view_model(
	state: GameStateType,
	contributions: Array[EffectContributionType]
) -> DashboardViewModelType:
	var revenue_cash_cents: int = 0
	var operating_cost_cash_cents: int = 0
	var project_cost_cash_cents: int = 0
	var cash_delta_cents: int = 0
	var progress_months: int = 0
	var completion_revenue_cents: int = 0
	for contribution in contributions:
		var reason_key: StringName = contribution.get_reason_key()
		var metric_key: StringName = contribution.get_metric_key()
		var unit: int = contribution.get_unit()
		var delta: int = contribution.get_delta()
		if (
			metric_key == EffectContributionType.METRIC_CASH_CENTS
			and unit == EffectContributionType.Unit.CENTS
		):
			if not _can_add(cash_delta_cents, delta):
				return null
			cash_delta_cents += delta
			if reason_key == EffectContributionType.REASON_MONTHLY_REVENUE:
				if not _can_add(revenue_cash_cents, delta):
					return null
				revenue_cash_cents += delta
			elif reason_key == EffectContributionType.REASON_MONTHLY_OPERATING_COST:
				if not _can_add(operating_cost_cash_cents, delta):
					return null
				operating_cost_cash_cents += delta
			elif reason_key == EffectContributionType.REASON_PROJECT_MONTHLY_COST:
				if not _can_add(project_cost_cash_cents, delta):
					return null
				project_cost_cash_cents += delta
		elif (
			reason_key == EffectContributionType.REASON_PROJECT_PROGRESS
			and metric_key == EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS
			and unit == EffectContributionType.Unit.MONTHS
		):
			if not _can_add(progress_months, delta):
				return null
			progress_months += delta
		elif (
			reason_key == EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE
			and metric_key == EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS
			and unit == EffectContributionType.Unit.CENTS
		):
			if not _can_add(completion_revenue_cents, delta):
				return null
			completion_revenue_cents += delta

	var company: CompanyStateType = state.get_company()
	var project: ProjectStateType = state.get_project()
	var clock: SimulationClockType = state.get_clock()
	var cash_after_cents: int = company.get_cash_cents()
	if not _can_subtract(cash_after_cents, cash_delta_cents):
		return null
	var cash_before_cents: int = cash_after_cents - cash_delta_cents
	var lifecycle_text: String = "UNKNOWN"
	var start_project_available: bool = false
	match project.get_lifecycle():
		ProjectStateType.Lifecycle.NOT_STARTED:
			lifecycle_text = "NOT STARTED"
			start_project_available = true
		ProjectStateType.Lifecycle.ACTIVE:
			lifecycle_text = "ACTIVE"
		ProjectStateType.Lifecycle.COMPLETED:
			lifecycle_text = "COMPLETED"

	return DashboardViewModelType.new(
		"AI COMPANY WAR",
		"%d Q%d" % [clock.get_year(), clock.get_quarter()],
		"Cash: %s cents" % _format_integer(cash_after_cents),
		"Monthly revenue: %s cents" % _format_integer(company.get_monthly_revenue_cents()),
		"Monthly operating cost: %s cents" % _format_integer(
			company.get_monthly_operating_cost_cents()
		),
		"Project: %s — %s %d/%d" % [
			String(project.get_project_id()),
			lifecycle_text,
			project.get_progress_months(),
			project.get_required_months(),
		],
		"START PROJECT" if start_project_available else "NEXT QUARTER",
		start_project_available,
		"Cash: %s → %s = %s cents" % [
			_format_integer(cash_before_cents),
			_format_integer(cash_after_cents),
			_format_signed_integer(cash_delta_cents),
		],
		"Revenue cash contributions: %s cents" % _format_signed_integer(
			revenue_cash_cents
		),
		"Operating-cost contributions: %s cents" % _format_signed_integer(
			operating_cost_cash_cents
		),
		"Project-cost contributions: %s cents" % _format_signed_integer(
			project_cost_cash_cents
		),
		"Project progress: %s months" % _format_signed_integer(progress_months),
		"Completion monthly revenue: %s cents" % _format_signed_integer(
			completion_revenue_cents
		)
	)


func _format_signed_integer(value: int) -> String:
	if value > 0:
		return "+%s" % _format_integer(value)
	return _format_integer(value)


func _can_add(value: int, delta: int) -> bool:
	if delta > 0:
		return value <= MAX_SIGNED_INT - delta
	if delta < 0:
		return value >= MIN_SIGNED_INT - delta
	return true


func _can_subtract(value: int, delta: int) -> bool:
	if delta > 0:
		return value >= MIN_SIGNED_INT + delta
	if delta < 0:
		return value <= MAX_SIGNED_INT + delta
	return true


func _format_integer(value: int) -> String:
	var digits: String = str(value)
	var is_negative: bool = digits.begins_with("-")
	if is_negative:
		digits = digits.substr(1)
	var formatted: String = ""
	while digits.length() > 3:
		var split_index: int = digits.length() - 3
		formatted = ",%s%s" % [digits.substr(split_index), formatted]
		digits = digits.substr(0, split_index)
	formatted = "%s%s" % [digits, formatted]
	return "-%s" % formatted if is_negative else formatted
