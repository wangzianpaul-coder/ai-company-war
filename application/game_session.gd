class_name GameSession
extends RefCounted


const GameCommandType = preload("res://simulation/commands/game_command.gd")
const CommandResultType = preload("res://simulation/commands/command_result.gd")
const StartProjectCommandType = preload("res://simulation/commands/start_project_command.gd")
const AdvanceQuarterCommandType = preload("res://simulation/commands/advance_quarter_command.gd")
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const SimulationEngineType = preload("res://simulation/engine/simulation_engine.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")
const SimulationClockType = preload("res://simulation/engine/simulation_clock.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const OpponentPlanningSnapshotType = preload(
	"res://simulation/ai/opponent_planning_snapshot.gd"
)
const OpponentPersonalityType = preload("res://simulation/ai/opponent_personality.gd")
const OpponentDecisionType = preload("res://simulation/ai/opponent_decision.gd")
const AiSystemType = preload("res://simulation/systems/ai_system.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const QuarterReportType = preload("res://simulation/reports/quarter_report.gd")
const QuarterReportBuilderType = preload("res://simulation/reports/quarter_report_builder.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const QuarterReportViewModelType = preload(
	"res://application/view_models/quarter_report_view_model.gd"
)
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1
const PROTOTYPE_QUARTER_LIMIT: int = 6
const MONTHS_PER_QUARTER: int = 3

signal committed_result(view_model: DashboardViewModelType)

var _engine: SimulationEngineType = SimulationEngineType.new()
var _active_state: GameStateType
var _last_committed_contributions: Array[EffectContributionType] = []
var _last_rival_contributions: Array[EffectContributionType] = []
var _current_view_model: DashboardViewModelType
var _personality: OpponentPersonalityType
var _cached_planning_snapshot: OpponentPlanningSnapshotType
var _cached_preview: OpponentDecisionType
var _prototype_start_elapsed_months: int
var _quarter_reports: Array[QuarterReportType] = []
var _quarter_report_view_models: Array[QuarterReportViewModelType] = []


## Takes ownership of independent state and an immutable injected personality.
func _init(
	p_initial_state: GameStateType,
	p_personality: OpponentPersonalityType = null
) -> void:
	if p_initial_state == null:
		_active_state = GameStateType.new()
	else:
		_active_state = p_initial_state.copy()
	_prototype_start_elapsed_months = _active_state.get_clock().get_elapsed_months()
	_personality = p_personality
	_cached_planning_snapshot = _create_planning_snapshot(_active_state)
	_cached_preview = _create_preview(
		_active_state,
		_cached_planning_snapshot,
		_personality
	)
	var no_contributions: Array[EffectContributionType] = []
	_current_view_model = _build_view_model(
		_active_state,
		no_contributions,
		_cached_preview,
		_last_rival_contributions,
		_quarter_report_view_models,
		0,
		false
	)


## Accepts only the three concrete commands and publishes only complete success.
func submit_command(command: GameCommandType) -> CommandResultType:
	if command == null:
		return CommandResultType.new(false)
	var committed_quarter_count: int = _derive_prototype_quarter_count(_active_state)
	if (
		committed_quarter_count < 0
		or committed_quarter_count != _quarter_reports.size()
		or committed_quarter_count != _quarter_report_view_models.size()
		or committed_quarter_count >= PROTOTYPE_QUARTER_LIMIT
	):
		return CommandResultType.new(false)
	if not _engine.is_opponent_boundary_valid(
		_active_state,
		_cached_planning_snapshot,
		_personality
	):
		return CommandResultType.new(false)
	if (
		_active_state.get_opponent().get_opponent_id() != &""
		and _cached_preview == null
	):
		return CommandResultType.new(false)

	var tick_result: TickResultType
	var advances_quarter: bool = false
	var before_quarter_state: GameStateType
	if command.get_script() == StartProjectCommandType:
		tick_result = _engine.start_project(_active_state)
	elif command.get_script() == AdvanceQuarterCommandType:
		advances_quarter = true
		before_quarter_state = _active_state.copy()
		if before_quarter_state == null:
			return CommandResultType.new(false)
		tick_result = _engine.advance_quarter(
			_active_state,
			_cached_planning_snapshot,
			_personality
		)
	elif command.get_script() == SetComputeAllocationCommandType:
		var allocation_command: SetComputeAllocationCommandType = (
			command as SetComputeAllocationCommandType
		)
		tick_result = _engine.set_compute_allocation(
			_active_state,
			allocation_command.get_training_units_per_month()
		)
	else:
		return CommandResultType.new(false)

	if tick_result == null or not tick_result.is_successful():
		return CommandResultType.new(false)
	var candidate_state: GameStateType = tick_result.get_state_snapshot()
	if candidate_state == null:
		return CommandResultType.new(false)
	var candidate_contributions: Array[EffectContributionType] = tick_result.get_contributions()
	var candidate_planning_snapshot: OpponentPlanningSnapshotType = (
		_cached_planning_snapshot
	)
	var candidate_preview: OpponentDecisionType = _cached_preview
	var candidate_rival_contributions: Array[EffectContributionType] = (
		_copy_contributions(_last_rival_contributions)
	)
	var candidate_quarter_count: int = committed_quarter_count
	var candidate_reports: Array[QuarterReportType] = _copy_reports(_quarter_reports)
	var candidate_report_view_models: Array[QuarterReportViewModelType] = (
		_copy_report_view_models(_quarter_report_view_models)
	)
	var candidate_prototype_complete: bool = false
	if advances_quarter:
		candidate_quarter_count = _derive_prototype_quarter_count(candidate_state)
		if (
			candidate_quarter_count != committed_quarter_count + 1
			or candidate_quarter_count > PROTOTYPE_QUARTER_LIMIT
			or candidate_state.get_clock().get_elapsed_months()
				< before_quarter_state.get_clock().get_elapsed_months()
			or candidate_state.get_clock().get_elapsed_months()
				- before_quarter_state.get_clock().get_elapsed_months()
				!= MONTHS_PER_QUARTER
		):
			return CommandResultType.new(false)
		candidate_prototype_complete = (
			candidate_quarter_count == PROTOTYPE_QUARTER_LIMIT
		)
		candidate_planning_snapshot = _create_planning_snapshot(candidate_state)
		if candidate_prototype_complete:
			candidate_preview = null
		else:
			candidate_preview = _create_preview(
				candidate_state,
				candidate_planning_snapshot,
				_personality
			)
			if (
				candidate_state.get_opponent().get_opponent_id() != &""
				and candidate_preview == null
			):
				return CommandResultType.new(false)
		candidate_rival_contributions = _extract_rival_contributions(
			candidate_contributions
		)
		var candidate_report: QuarterReportType = QuarterReportBuilderType.new().build(
			before_quarter_state,
			tick_result,
			candidate_preview,
			candidate_quarter_count,
			candidate_prototype_complete
		)
		if candidate_report == null or not candidate_report.is_valid():
			return CommandResultType.new(false)
		var opponent_display_name: String = (
			"" if _personality == null else _personality.get_display_name()
		)
		var candidate_report_view_model: QuarterReportViewModelType = (
			QuarterReportViewModelType.new(candidate_report, opponent_display_name)
		)
		if (
			candidate_report_view_model == null
			or not candidate_report_view_model.is_valid()
		):
			return CommandResultType.new(false)
		candidate_reports.append(candidate_report)
		candidate_report_view_models.append(candidate_report_view_model)
		if (
			candidate_reports.size() != candidate_quarter_count
			or candidate_report_view_models.size() != candidate_quarter_count
		):
			return CommandResultType.new(false)
	var candidate_view_model: DashboardViewModelType = _build_view_model(
		candidate_state,
		candidate_contributions,
		candidate_preview,
		candidate_rival_contributions,
		candidate_report_view_models,
		candidate_quarter_count,
		candidate_prototype_complete
	)
	if candidate_view_model == null:
		return CommandResultType.new(false)

	_active_state = candidate_state
	_last_committed_contributions.clear()
	for contribution in candidate_contributions:
		_last_committed_contributions.append(contribution)
	if advances_quarter:
		_cached_planning_snapshot = candidate_planning_snapshot
		_cached_preview = candidate_preview
		_last_rival_contributions = candidate_rival_contributions
		_quarter_reports = candidate_reports
		_quarter_report_view_models = candidate_report_view_models
	_current_view_model = candidate_view_model
	committed_result.emit(_current_view_model)
	return CommandResultType.new(true)


## Returns an independent snapshot for tests and non-UI inspection.
func get_state_snapshot() -> GameStateType:
	return _active_state.copy()


## Returns a typed array copy preserving the committed source order.
func get_last_committed_contributions() -> Array[EffectContributionType]:
	return _copy_contributions(_last_committed_contributions)


## Returns the cached public quarter boundary without exposing session ownership.
func get_cached_opponent_planning_snapshot() -> OpponentPlanningSnapshotType:
	return _cached_planning_snapshot.copy()


## Returns an ordered array copy of only the last committed rival economy slice.
func get_last_rival_contributions() -> Array[EffectContributionType]:
	return _copy_contributions(_last_rival_contributions)


## Returns the committed Prototype count derived from elapsed months.
func get_prototype_quarter_count() -> int:
	return _derive_prototype_quarter_count(_active_state)


func is_prototype_complete() -> bool:
	return get_prototype_quarter_count() == PROTOTYPE_QUARTER_LIMIT


## Returns fully independent immutable report copies in committed quarter order.
func get_quarter_reports() -> Array[QuarterReportType]:
	return _copy_reports(_quarter_reports)


## Exposes only whether a non-consuming next decision is cached.
func has_cached_opponent_preview() -> bool:
	return _cached_preview != null


## Returns the current immutable-by-interface display values.
func get_current_view_model() -> DashboardViewModelType:
	return _current_view_model


func _build_view_model(
	state: GameStateType,
	contributions: Array[EffectContributionType],
	preview: OpponentDecisionType,
	rival_contributions: Array[EffectContributionType],
	report_view_models: Array[QuarterReportViewModelType],
	prototype_quarter_count: int,
	prototype_complete: bool
) -> DashboardViewModelType:
	if (
		prototype_quarter_count < 0
		or prototype_quarter_count > PROTOTYPE_QUARTER_LIMIT
		or prototype_complete
			!= (prototype_quarter_count == PROTOTYPE_QUARTER_LIMIT)
		or report_view_models.size() != prototype_quarter_count
	):
		return null
	var revenue_cash_cents: int = 0
	var operating_cost_cash_cents: int = 0
	var project_cost_cash_cents: int = 0
	var cash_delta_cents: int = 0
	var progress_months: int = 0
	var completion_revenue_cents: int = 0
	var training_work_compute_unit_months: int = 0
	var served_inference_compute_unit_months: int = 0
	var unmet_inference_compute_unit_months: int = 0
	var consumer_market_served_compute_unit_months: int = 0
	var consumer_market_unmet_compute_unit_months: int = 0
	var consumer_market_share_delta_bps: int = 0
	var consumer_market_revenue_delta_cents: int = 0
	var developer_api_market_served_compute_unit_months: int = 0
	var developer_api_market_unmet_compute_unit_months: int = 0
	var developer_api_market_share_delta_bps: int = 0
	var developer_api_market_revenue_delta_cents: int = 0
	var has_market_contributions: bool = false
	for contribution in contributions:
		var source_key: StringName = contribution.get_source_key()
		var reason_key: StringName = contribution.get_reason_key()
		var subject_key: StringName = contribution.get_subject_key()
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
		elif (
			source_key == EffectContributionType.SOURCE_COMPUTE
			and reason_key == EffectContributionType.REASON_TRAINING_WORK
			and subject_key == EffectContributionType.SUBJECT_COMPANY
			and metric_key
				== EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS
			and unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
		):
			if not _can_add(training_work_compute_unit_months, delta):
				return null
			training_work_compute_unit_months += delta
		elif (
			source_key == EffectContributionType.SOURCE_COMPUTE
			and reason_key == EffectContributionType.REASON_INFERENCE_SERVED
			and subject_key == EffectContributionType.SUBJECT_COMPANY
			and metric_key
				== EffectContributionType.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
			and unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
		):
			if not _can_add(served_inference_compute_unit_months, delta):
				return null
			served_inference_compute_unit_months += delta
		elif (
			source_key == EffectContributionType.SOURCE_COMPUTE
			and reason_key == EffectContributionType.REASON_INFERENCE_UNMET
			and subject_key == EffectContributionType.SUBJECT_COMPANY
			and metric_key
				== EffectContributionType.METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
			and unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
		):
			if not _can_add(unmet_inference_compute_unit_months, delta):
				return null
			unmet_inference_compute_unit_months += delta
		elif source_key == EffectContributionType.SOURCE_MARKET:
			has_market_contributions = true
			if (
				reason_key == EffectContributionType.REASON_MARKET_SERVED
				and metric_key
					== EffectContributionType.METRIC_CUMULATIVE_MARKET_SERVED_COMPUTE_UNIT_MONTHS
				and unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
				and delta >= 0
			):
				if subject_key == EffectContributionType.SUBJECT_CONSUMER:
					if not _can_add(consumer_market_served_compute_unit_months, delta):
						return null
					consumer_market_served_compute_unit_months += delta
				elif subject_key == EffectContributionType.SUBJECT_DEVELOPER_API:
					if not _can_add(developer_api_market_served_compute_unit_months, delta):
						return null
					developer_api_market_served_compute_unit_months += delta
				else:
					return null
			elif (
				reason_key == EffectContributionType.REASON_MARKET_UNMET
				and metric_key
					== EffectContributionType.METRIC_CUMULATIVE_MARKET_UNMET_COMPUTE_UNIT_MONTHS
				and unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
				and delta >= 0
			):
				if subject_key == EffectContributionType.SUBJECT_CONSUMER:
					if not _can_add(consumer_market_unmet_compute_unit_months, delta):
						return null
					consumer_market_unmet_compute_unit_months += delta
				elif subject_key == EffectContributionType.SUBJECT_DEVELOPER_API:
					if not _can_add(developer_api_market_unmet_compute_unit_months, delta):
						return null
					developer_api_market_unmet_compute_unit_months += delta
				else:
					return null
			elif (
				(
					reason_key == EffectContributionType.REASON_MARKET_SHARE_CHANGE
					or reason_key
						== EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
				)
				and metric_key == EffectContributionType.METRIC_PLAYER_SHARE_BPS
				and unit == EffectContributionType.Unit.BASIS_POINTS
			):
				if subject_key == EffectContributionType.SUBJECT_CONSUMER:
					if not _can_add(consumer_market_share_delta_bps, delta):
						return null
					consumer_market_share_delta_bps += delta
				elif subject_key == EffectContributionType.SUBJECT_DEVELOPER_API:
					if not _can_add(developer_api_market_share_delta_bps, delta):
						return null
					developer_api_market_share_delta_bps += delta
				else:
					return null
			elif (
				reason_key == EffectContributionType.REASON_MARKET_REVENUE_CHANGE
				and metric_key == EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS
				and unit == EffectContributionType.Unit.CENTS
			):
				if subject_key == EffectContributionType.SUBJECT_CONSUMER:
					if not _can_add(consumer_market_revenue_delta_cents, delta):
						return null
					consumer_market_revenue_delta_cents += delta
				elif subject_key == EffectContributionType.SUBJECT_DEVELOPER_API:
					if not _can_add(developer_api_market_revenue_delta_cents, delta):
						return null
					developer_api_market_revenue_delta_cents += delta
				else:
					return null
			else:
				return null

	if not _can_add(
		served_inference_compute_unit_months,
		unmet_inference_compute_unit_months
	):
		return null
	var inference_workload_compute_unit_months: int = (
		served_inference_compute_unit_months + unmet_inference_compute_unit_months
	)

	var company: CompanyStateType = state.get_company()
	var project: ProjectStateType = state.get_project()
	var compute: ComputeStateType = state.get_compute()
	var market: MarketStateType = state.get_market()
	var clock: SimulationClockType = state.get_clock()
	if market == null:
		return null
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

	var consumer_market_text: String = (
		"Consumer: %s bps | workload %s | %s cents/month" % [
			_format_integer(market.get_consumer_player_share_bps()),
			_format_integer(market.get_consumer_workload_units_per_month()),
			_format_integer(market.get_consumer_current_market_revenue_cents()),
		]
	)
	var developer_api_market_text: String = (
		"Developer/API: %s bps | workload %s | %s cents/month" % [
			_format_integer(market.get_developer_api_player_share_bps()),
			_format_integer(market.get_developer_api_workload_units_per_month()),
			_format_integer(market.get_developer_api_current_market_revenue_cents()),
		]
	)
	if has_market_contributions:
		if (
			not _can_add(
				consumer_market_served_compute_unit_months,
				consumer_market_unmet_compute_unit_months
			)
			or not _can_add(
				developer_api_market_served_compute_unit_months,
				developer_api_market_unmet_compute_unit_months
			)
		):
			return null
		var consumer_market_demand_compute_unit_months: int = (
			consumer_market_served_compute_unit_months
			+ consumer_market_unmet_compute_unit_months
		)
		var developer_api_market_demand_compute_unit_months: int = (
			developer_api_market_served_compute_unit_months
			+ developer_api_market_unmet_compute_unit_months
		)
		consumer_market_text = "Consumer: served %s/%s, share %s → %s bps, revenue %s → %s" % [
			_format_integer(consumer_market_served_compute_unit_months),
			_format_integer(consumer_market_demand_compute_unit_months),
			_format_signed_integer(consumer_market_share_delta_bps),
			_format_integer(market.get_consumer_player_share_bps()),
			_format_signed_integer(consumer_market_revenue_delta_cents),
			_format_integer(market.get_consumer_current_market_revenue_cents()),
		]
		developer_api_market_text = (
			"Developer/API: served %s/%s, share %s → %s bps, revenue %s → %s" % [
				_format_integer(developer_api_market_served_compute_unit_months),
				_format_integer(developer_api_market_demand_compute_unit_months),
				_format_signed_integer(developer_api_market_share_delta_bps),
				_format_integer(market.get_developer_api_player_share_bps()),
				_format_signed_integer(developer_api_market_revenue_delta_cents),
				_format_integer(market.get_developer_api_current_market_revenue_cents()),
			]
		)

	var rival_signal_text: String = ""
	var rival_reason_text: String = ""
	var rival_utility_text: String = ""
	var rival_last_action_text: String = ""
	var rival_quarter_text: String = ""
	var rival_market_pressure_text: String = ""
	if prototype_complete:
		if preview != null:
			return null
		rival_signal_text = "Prototype complete — no next signal"
		rival_reason_text = "Why: Prototype complete"
		rival_utility_text = "Utility: —"
	var opponent: OpponentStateType = state.get_opponent()
	if (
		opponent != null
		and opponent.get_opponent_id() != &""
		and _personality != null
	):
		var opponent_compute: ComputeStateType = opponent.get_compute()
		var allocatable_units: int = (
			opponent_compute.get_allocatable_capacity_units_per_month()
		)
		var has_committed_rival_quarter: bool = not rival_contributions.is_empty()
		if not prototype_complete:
			if preview == null or not preview.is_successful():
				return null
			var preview_command: SetComputeAllocationCommandType = preview.get_command()
			if (
				preview_command == null
				or preview_command.get_script() != SetComputeAllocationCommandType
			):
				return null
			var preview_training_units: int = (
				preview_command.get_training_units_per_month()
			)
			if preview_training_units < 0 or preview_training_units > allocatable_units:
				return null
			var preview_inference_units: int = allocatable_units - preview_training_units
			var reason_display: String = _reason_display_text(preview.get_reason_key())
			if reason_display.is_empty():
				return null
			if has_committed_rival_quarter:
				rival_signal_text = (
					"Next signal: %s training / %s inference — %s" % [
						_format_integer(preview_training_units),
						_format_integer(preview_inference_units),
						reason_display,
					]
				)
			else:
				rival_signal_text = "%s signal: %s training / %s inference" % [
					_personality.get_display_name(),
					_format_integer(preview_training_units),
					_format_integer(preview_inference_units),
				]
			rival_reason_text = "Why: %s" % reason_display
			rival_utility_text = "Utility: %s = %s + %s seeded noise" % [
				_format_integer(preview.get_total_utility_points()),
				_format_integer(preview.get_base_utility_points()),
				_format_integer(preview.get_noise_points()),
			]
		rival_last_action_text = "Last action: —"
		rival_quarter_text = "Quarter: —"
		rival_market_pressure_text = "Market pressure: —"
		if has_committed_rival_quarter:
			var last_training_units: int = (
				opponent.get_last_training_units_per_month()
			)
			if last_training_units < 0 or last_training_units > allocatable_units:
				return null
			var rival_training_work: int = 0
			var rival_served_inference: int = 0
			var rival_unmet_inference: int = 0
			var consumer_pressure_bps: int = 0
			var developer_api_pressure_bps: int = 0
			for rival_contribution in rival_contributions:
				var rival_source: StringName = rival_contribution.get_source_key()
				var rival_reason: StringName = rival_contribution.get_reason_key()
				var rival_subject: StringName = rival_contribution.get_subject_key()
				var rival_metric: StringName = rival_contribution.get_metric_key()
				var rival_unit: int = rival_contribution.get_unit()
				var rival_delta: int = rival_contribution.get_delta()
				if (
					rival_source == EffectContributionType.SOURCE_COMPUTE
					and rival_subject == EffectContributionType.SUBJECT_NORTHSTAR_LABS
					and rival_reason == EffectContributionType.REASON_TRAINING_WORK
					and rival_metric
						== EffectContributionType.METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS
					and rival_unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
				):
					if not _can_add(rival_training_work, rival_delta):
						return null
					rival_training_work += rival_delta
				elif (
					rival_source == EffectContributionType.SOURCE_COMPUTE
					and rival_subject == EffectContributionType.SUBJECT_NORTHSTAR_LABS
					and rival_reason == EffectContributionType.REASON_INFERENCE_SERVED
					and rival_metric
						== EffectContributionType.METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
					and rival_unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
				):
					if not _can_add(rival_served_inference, rival_delta):
						return null
					rival_served_inference += rival_delta
				elif (
					rival_source == EffectContributionType.SOURCE_COMPUTE
					and rival_subject == EffectContributionType.SUBJECT_NORTHSTAR_LABS
					and rival_reason == EffectContributionType.REASON_INFERENCE_UNMET
					and rival_metric
						== EffectContributionType.METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
					and rival_unit == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
				):
					if not _can_add(rival_unmet_inference, rival_delta):
						return null
					rival_unmet_inference += rival_delta
				elif (
					rival_source == EffectContributionType.SOURCE_MARKET
					and rival_reason
						== EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
					and rival_metric == EffectContributionType.METRIC_PLAYER_SHARE_BPS
					and rival_unit == EffectContributionType.Unit.BASIS_POINTS
				):
					if rival_subject == EffectContributionType.SUBJECT_CONSUMER:
						if not _can_add(consumer_pressure_bps, rival_delta):
							return null
						consumer_pressure_bps += rival_delta
					elif rival_subject == EffectContributionType.SUBJECT_DEVELOPER_API:
						if not _can_add(developer_api_pressure_bps, rival_delta):
							return null
						developer_api_pressure_bps += rival_delta
					else:
						return null
				else:
					return null
			if not _can_add(rival_served_inference, rival_unmet_inference):
				return null
			var rival_inference_workload: int = (
				rival_served_inference + rival_unmet_inference
			)
			rival_last_action_text = "Last action: %s training / %s inference" % [
				_format_integer(last_training_units),
				_format_integer(allocatable_units - last_training_units),
			]
			rival_quarter_text = (
				"Quarter: %s training; inference %s/%s; unmet %s" % [
					_format_signed_integer(rival_training_work),
					_format_integer(rival_served_inference),
					_format_integer(rival_inference_workload),
					_format_integer(rival_unmet_inference),
				]
			)
			rival_market_pressure_text = (
				"Market pressure: Consumer %s bps; Developer/API %s bps" % [
					_format_signed_integer(consumer_pressure_bps),
					_format_signed_integer(developer_api_pressure_bps),
				]
			)

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
		(
			"PROTOTYPE COMPLETE"
			if prototype_complete
			else ("START PROJECT" if start_project_available else "NEXT QUARTER")
		),
		start_project_available and not prototype_complete,
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
		),
		"Compute/month: %s = %s training + %s inference + %s reserve" % [
			_format_integer(compute.get_total_units_per_month()),
			_format_integer(compute.get_training_allocation_units_per_month()),
			_format_integer(compute.get_inference_allocation_units_per_month()),
			_format_integer(compute.get_reserve_units_per_month()),
		],
		"Inference workload: %s units/month" % _format_integer(
			compute.get_inference_workload_units_per_month()
		),
		compute.get_training_allocation_units_per_month(),
		compute.get_allocatable_capacity_units_per_month(),
		"Training work: %s compute-unit-months" % _format_signed_integer(
			training_work_compute_unit_months
		),
		"Inference served: %s/%s compute-unit-months" % [
			_format_integer(served_inference_compute_unit_months),
			_format_integer(inference_workload_compute_unit_months),
		],
		"Inference unmet: %s compute-unit-months" % _format_integer(
			unmet_inference_compute_unit_months
		),
		consumer_market_text,
		developer_api_market_text,
		rival_signal_text,
		rival_reason_text,
		rival_utility_text,
		rival_last_action_text,
		rival_quarter_text,
		rival_market_pressure_text,
		(
			"Prototype complete: 6/6"
			if prototype_complete
			else "Prototype quarter: %d/6" % prototype_quarter_count
		),
		prototype_quarter_count,
		prototype_complete,
		not prototype_complete,
		report_view_models
	)


func _create_planning_snapshot(state: GameStateType) -> OpponentPlanningSnapshotType:
	return OpponentPlanningSnapshotType.new(
		state.get_clock().get_elapsed_months(),
		state.get_market().get_consumer_player_share_bps(),
		state.get_market().get_developer_api_player_share_bps()
	)


func _create_preview(
	state: GameStateType,
	snapshot: OpponentPlanningSnapshotType,
	personality: OpponentPersonalityType
) -> OpponentDecisionType:
	if (
		state.get_opponent().get_opponent_id() == &""
		or personality == null
		or snapshot == null
	):
		return null
	var preview: OpponentDecisionType = AiSystemType.new().decide(
		snapshot,
		state.get_opponent(),
		personality,
		state.get_named_rng()
	)
	return preview if preview != null and preview.is_successful() else null


func _extract_rival_contributions(
	contributions: Array[EffectContributionType]
) -> Array[EffectContributionType]:
	var rival_contributions: Array[EffectContributionType] = []
	for contribution in contributions:
		if (
			(
				contribution.get_source_key() == EffectContributionType.SOURCE_COMPUTE
				and contribution.get_subject_key()
					== EffectContributionType.SUBJECT_NORTHSTAR_LABS
			)
			or (
				contribution.get_source_key() == EffectContributionType.SOURCE_MARKET
				and contribution.get_reason_key()
					== EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
			)
		):
			rival_contributions.append(contribution)
	return rival_contributions


func _copy_contributions(
	contributions: Array[EffectContributionType]
) -> Array[EffectContributionType]:
	var copied_contributions: Array[EffectContributionType] = []
	for contribution in contributions:
		copied_contributions.append(contribution)
	return copied_contributions


func _copy_reports(reports: Array[QuarterReportType]) -> Array[QuarterReportType]:
	var copied_reports: Array[QuarterReportType] = []
	for report in reports:
		if report == null:
			return []
		var copied_report: QuarterReportType = report.copy()
		if copied_report == null or not copied_report.is_valid():
			return []
		copied_reports.append(copied_report)
	return copied_reports


func _copy_report_view_models(
	view_models: Array[QuarterReportViewModelType]
) -> Array[QuarterReportViewModelType]:
	var copied_view_models: Array[QuarterReportViewModelType] = []
	for view_model in view_models:
		if view_model == null or not view_model.is_valid():
			return []
		copied_view_models.append(view_model)
	return copied_view_models


func _derive_prototype_quarter_count(state: GameStateType) -> int:
	if state == null or state.get_clock() == null:
		return -1
	var elapsed_months: int = state.get_clock().get_elapsed_months()
	if elapsed_months < _prototype_start_elapsed_months:
		return -1
	var prototype_elapsed_months: int = elapsed_months - _prototype_start_elapsed_months
	if prototype_elapsed_months % MONTHS_PER_QUARTER != 0:
		return -1
	var quarter_count: int = prototype_elapsed_months / MONTHS_PER_QUARTER
	if quarter_count < 0 or quarter_count > PROTOTYPE_QUARTER_LIMIT:
		return -1
	return quarter_count


func _reason_display_text(reason_key: StringName) -> String:
	match reason_key:
		OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION:
			return "Defend market position"
		OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP:
			return "Close training gap"
	return ""


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
