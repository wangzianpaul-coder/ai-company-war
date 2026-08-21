extends RefCounted


const GameCommandType = preload("res://simulation/commands/game_command.gd")
const StartProjectCommandType = preload("res://simulation/commands/start_project_command.gd")
const AdvanceQuarterCommandType = preload("res://simulation/commands/advance_quarter_command.gd")
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const SimulationEngineType = preload("res://simulation/engine/simulation_engine.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const PROJECT_ID: StringName = &"project_alpha"


class UnknownGameCommand:
	extends GameCommandType


class DerivedSetComputeAllocationCommand:
	extends SetComputeAllocationCommandType

	func _init(p_training_units_per_month: int) -> void:
		super(p_training_units_per_month)


class CommitObserver:
	extends RefCounted

	var count: int = 0
	var last_view_model: DashboardViewModelType
	var allocation_was_committed_before_signal: bool = false
	var _session

	func _init(p_session) -> void:
		_session = p_session

	func capture(view_model: DashboardViewModelType) -> void:
		count += 1
		last_view_model = view_model
		if count == 1:
			var snapshot: GameStateType = _session.get_state_snapshot()
			allocation_was_committed_before_signal = (
				snapshot.get_compute().get_training_allocation_units_per_month() == 70
				and _session.get_last_committed_contributions().is_empty()
				and _session.get_current_view_model() == view_model
			)


static func run(report: Callable) -> void:
	_test_quarter_order_and_rollback(report)
	_test_game_session_boundary(report)
	_test_fixed_plan_sessions(report)


static func report_dashboard_scene(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-020 dashboard exposes the fixed compute tradeoff"
	)


static func report_dashboard_layout(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-020 dashboard fits 1280x720 and 1920x1080"
	)


static func _test_quarter_order_and_rollback(report: Callable) -> void:
	var engine: SimulationEngineType = SimulationEngineType.new()
	var zero_state: GameStateType = _create_active_state(ComputeStateType.new())
	var zero_before: GameStateType = zero_state.copy()
	var zero_result: TickResultType = engine.advance_quarter(zero_state)
	var zero_trace: Array[EffectContributionType] = zero_result.get_contributions()
	var zero_compatible: bool = (
		zero_result.is_successful()
		and zero_trace.size() == 13
		and _game_states_equal(zero_state, zero_before)
	)
	for contribution in zero_trace:
		zero_compatible = (
			contribution.get_source_key() != EffectContributionType.SOURCE_COMPUTE
			and zero_compatible
		)

	var default_result: TickResultType = engine.advance_quarter(
		_create_active_state(ComputeStateType.new(100, 10, 50, 40))
	)
	var default_state: GameStateType = default_result.get_state_snapshot()
	var default_exact: bool = (
		default_result.is_successful()
		and default_result.get_contributions().size() == 19
		and default_state.get_compute().get_cumulative_training_compute_unit_months()
			== 120
		and default_state.get_compute()
			.get_cumulative_served_inference_compute_unit_months() == 150
		and default_state.get_compute()
			.get_cumulative_unmet_inference_compute_unit_months() == 0
	)

	var constrained_result: TickResultType = engine.advance_quarter(
		_create_active_state(ComputeStateType.new(100, 10, 50, 70))
	)
	var constrained_state: GameStateType = constrained_result.get_state_snapshot()
	var constrained_trace: Array[EffectContributionType] = (
		constrained_result.get_contributions()
	)
	var constrained_exact: bool = (
		constrained_result.is_successful()
		and constrained_trace.size() == 22
		and constrained_state.get_clock().get_elapsed_months() == 3
		and constrained_state.get_compute().get_cumulative_training_compute_unit_months()
			== 210
		and constrained_state.get_compute()
			.get_cumulative_served_inference_compute_unit_months() == 60
		and constrained_state.get_compute()
			.get_cumulative_unmet_inference_compute_unit_months() == 90
		and _reason_delta_matches(
			constrained_trace,
			0,
			EffectContributionType.REASON_PROJECT_MONTHLY_COST,
			-25_000
		)
		and _reason_delta_matches(
			constrained_trace,
			1,
			EffectContributionType.REASON_PROJECT_PROGRESS,
			1
		)
		and _compute_reason_delta_matches(
			constrained_trace,
			2,
			EffectContributionType.REASON_TRAINING_WORK,
			70
		)
		and _compute_reason_delta_matches(
			constrained_trace,
			3,
			EffectContributionType.REASON_INFERENCE_SERVED,
			20
		)
		and _compute_reason_delta_matches(
			constrained_trace,
			4,
			EffectContributionType.REASON_INFERENCE_UNMET,
			30
		)
		and _reason_delta_matches(
			constrained_trace,
			5,
			EffectContributionType.REASON_MONTHLY_REVENUE,
			120_000
		)
		and _reason_delta_matches(
			constrained_trace,
			6,
			EffectContributionType.REASON_MONTHLY_OPERATING_COST,
			-80_000
		)
		and _reason_delta_matches(
			constrained_trace,
			16,
			EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE,
			30_000
		)
		and _compute_reason_delta_matches(
			constrained_trace,
			17,
			EffectContributionType.REASON_TRAINING_WORK,
			70
		)
		and _reason_delta_matches(
			constrained_trace,
			20,
			EffectContributionType.REASON_MONTHLY_REVENUE,
			150_000
		)
	)

	var all_failures_atomic: bool = true
	for failure_month in range(1, 4):
		var overflow_compute: ComputeStateType = ComputeStateType.new(
			0,
			0,
			1,
			0,
			0,
			0,
			MAX_SIGNED_INT - failure_month + 1
		)
		var failure_state: GameStateType = GameStateType.new(
			CompanyStateType.new(),
			ProjectStateType.new(
				PROJECT_ID,
				4,
				0,
				0,
				ProjectStateType.Lifecycle.ACTIVE,
				0
			),
			overflow_compute
		)
		var before_failure: GameStateType = failure_state.copy()
		var failure_result: TickResultType = engine.advance_quarter(failure_state)
		all_failures_atomic = (
			not failure_result.is_successful()
			and failure_result.get_state_snapshot() == null
			and failure_result.get_contributions().is_empty()
			and _game_states_equal(failure_state, before_failure)
			and all_failures_atomic
		)
	_report(
		report,
		zero_compatible and default_exact and constrained_exact and all_failures_atomic,
		"TP-020 compute quarter preserves ordered effects and rollback"
	)


static func _test_game_session_boundary(report: Callable) -> void:
	var session: GameSessionType = GameSessionType.new(_create_demo_state())
	var observer: CommitObserver = CommitObserver.new(session)
	session.committed_result.connect(Callable(observer, "capture"))
	var initial_state: GameStateType = session.get_state_snapshot()
	var initial_view_model: DashboardViewModelType = session.get_current_view_model()

	var null_command: GameCommandType = null
	var null_rejected: bool = not session.submit_command(null_command).is_successful()
	var base_rejected: bool = not session.submit_command(GameCommandType.new()).is_successful()
	var unknown_rejected: bool = not session.submit_command(UnknownGameCommand.new()).is_successful()
	var derived_rejected: bool = not session.submit_command(
		DerivedSetComputeAllocationCommand.new(70)
	).is_successful()
	var negative_rejected: bool = not session.submit_command(
		SetComputeAllocationCommandType.new(-1)
	).is_successful()
	var excessive_rejected: bool = not session.submit_command(
		SetComputeAllocationCommandType.new(91)
	).is_successful()
	var initial_rejections_preserved: bool = (
		null_rejected
		and base_rejected
		and unknown_rejected
		and derived_rejected
		and negative_rejected
		and excessive_rejected
		and observer.count == 0
		and session.get_current_view_model() == initial_view_model
		and session.get_last_committed_contributions().is_empty()
		and _game_states_equal(session.get_state_snapshot(), initial_state)
	)

	var allocation_succeeded: bool = session.submit_command(
		SetComputeAllocationCommandType.new(70)
	).is_successful()
	var allocated_state: GameStateType = session.get_state_snapshot()
	var allocated_view_model: DashboardViewModelType = session.get_current_view_model()
	var allocation_exact: bool = (
		allocation_succeeded
		and observer.count == 1
		and observer.last_view_model == allocated_view_model
		and observer.allocation_was_committed_before_signal
		and allocated_state.get_clock().get_elapsed_months() == 0
		and allocated_state.get_company().get_cash_cents() == 1_000_000
		and allocated_state.get_project().get_lifecycle()
			== ProjectStateType.Lifecycle.NOT_STARTED
		and allocated_state.get_compute().get_training_allocation_units_per_month() == 70
		and allocated_state.get_compute().get_inference_allocation_units_per_month() == 20
		and allocated_state.get_compute().get_cumulative_training_compute_unit_months() == 0
		and session.get_last_committed_contributions().is_empty()
		and allocated_view_model.get_compute_plan_text()
			== "Compute/month: 100 = 70 training + 20 inference + 10 reserve"
		and allocated_view_model.get_training_work_text()
			== "Training work: 0 compute-unit-months"
		and allocated_view_model.get_inference_served_text()
			== "Inference served: 0/0 compute-unit-months"
	)

	var before_late_rejection: GameStateType = session.get_state_snapshot()
	var before_late_view_model: DashboardViewModelType = session.get_current_view_model()
	var late_rejected: bool = not session.submit_command(
		SetComputeAllocationCommandType.new(100)
	).is_successful()
	var late_rejection_preserved: bool = (
		late_rejected
		and observer.count == 1
		and session.get_current_view_model() == before_late_view_model
		and session.get_last_committed_contributions().is_empty()
		and _game_states_equal(session.get_state_snapshot(), before_late_rejection)
	)

	var started: bool = session.submit_command(StartProjectCommandType.new()).is_successful()
	var advanced: bool = session.submit_command(AdvanceQuarterCommandType.new()).is_successful()
	var final_state: GameStateType = session.get_state_snapshot()
	var final_view_model: DashboardViewModelType = session.get_current_view_model()
	var quarter_exact: bool = (
		started
		and advanced
		and observer.count == 3
		and final_state.get_clock().get_elapsed_months() == 3
		and final_state.get_company().get_cash_cents() == 1_075_000
		and final_state.get_project().get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED
		and final_state.get_compute().get_cumulative_training_compute_unit_months() == 210
		and final_state.get_compute()
			.get_cumulative_served_inference_compute_unit_months() == 60
		and final_state.get_compute()
			.get_cumulative_unmet_inference_compute_unit_months() == 90
		and final_view_model.get_training_work_text()
			== "Training work: +210 compute-unit-months"
		and final_view_model.get_inference_served_text()
			== "Inference served: 60/150 compute-unit-months"
		and final_view_model.get_inference_unmet_text()
			== "Inference unmet: 90 compute-unit-months"
	)
	_report(
		report,
		initial_rejections_preserved
			and allocation_exact
			and late_rejection_preserved
			and quarter_exact,
		"TP-020 GameSession commits only valid compute plans"
	)


static func _test_fixed_plan_sessions(report: Callable) -> void:
	var default_session: GameSessionType = GameSessionType.new(_create_demo_state())
	var default_success: bool = (
		default_session.submit_command(StartProjectCommandType.new()).is_successful()
		and default_session.submit_command(AdvanceQuarterCommandType.new()).is_successful()
	)
	var default_view_model: DashboardViewModelType = default_session.get_current_view_model()
	var default_exact: bool = (
		default_success
		and default_view_model.get_training_work_text()
			== "Training work: +120 compute-unit-months"
		and default_view_model.get_inference_served_text()
			== "Inference served: 150/150 compute-unit-months"
		and default_view_model.get_inference_unmet_text()
			== "Inference unmet: 0 compute-unit-months"
	)

	var first: GameSessionType = GameSessionType.new(_create_demo_state())
	var second: GameSessionType = GameSessionType.new(_create_demo_state())
	var constrained_success: bool = true
	for session in [first, second]:
		constrained_success = (
			session.submit_command(SetComputeAllocationCommandType.new(70)).is_successful()
			and session.submit_command(StartProjectCommandType.new()).is_successful()
			and session.submit_command(AdvanceQuarterCommandType.new()).is_successful()
			and constrained_success
		)
	var first_view_model: DashboardViewModelType = first.get_current_view_model()
	var equivalent: bool = (
		constrained_success
		and _game_states_equal(first.get_state_snapshot(), second.get_state_snapshot())
		and _traces_equal(
			first.get_last_committed_contributions(),
			second.get_last_committed_contributions()
		)
		and first_view_model.get_training_work_text()
			== "Training work: +210 compute-unit-months"
		and first_view_model.get_inference_served_text()
			== "Inference served: 60/150 compute-unit-months"
		and first_view_model.get_inference_unmet_text()
			== "Inference unmet: 90 compute-unit-months"
		and first.get_state_snapshot().get_company().get_cash_cents()
			== default_session.get_state_snapshot().get_company().get_cash_cents()
		and first.get_state_snapshot().get_project().get_progress_months()
			== default_session.get_state_snapshot().get_project().get_progress_months()
	)
	_report(
		report,
		default_exact and equivalent,
		"TP-020 default and constrained sessions remain deterministic"
	)


static func _create_demo_state() -> GameStateType:
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		ProjectStateType.new(PROJECT_ID, 3, 25_000, 30_000),
		ComputeStateType.new(100, 10, 50, 40)
	)


static func _create_active_state(compute: ComputeStateType) -> GameStateType:
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		ProjectStateType.new(
			PROJECT_ID,
			3,
			25_000,
			30_000,
			ProjectStateType.Lifecycle.ACTIVE,
			0
		),
		compute
	)


static func _game_states_equal(first: GameStateType, second: GameStateType) -> bool:
	if first == null or second == null:
		return first == second
	return (
		first.get_clock().get_elapsed_months() == second.get_clock().get_elapsed_months()
		and first.get_company().get_cash_cents() == second.get_company().get_cash_cents()
		and first.get_company().get_monthly_revenue_cents()
			== second.get_company().get_monthly_revenue_cents()
		and first.get_company().get_monthly_operating_cost_cents()
			== second.get_company().get_monthly_operating_cost_cents()
		and first.get_project().get_project_id() == second.get_project().get_project_id()
		and first.get_project().get_lifecycle() == second.get_project().get_lifecycle()
		and first.get_project().get_required_months()
			== second.get_project().get_required_months()
		and first.get_project().get_progress_months()
			== second.get_project().get_progress_months()
		and first.get_project().get_monthly_cost_cents()
			== second.get_project().get_monthly_cost_cents()
		and first.get_project().get_completion_monthly_revenue_delta_cents()
			== second.get_project().get_completion_monthly_revenue_delta_cents()
		and _compute_states_equal(first.get_compute(), second.get_compute())
	)


static func _compute_states_equal(first: ComputeStateType, second: ComputeStateType) -> bool:
	return (
		first.get_total_units_per_month() == second.get_total_units_per_month()
		and first.get_reserve_units_per_month() == second.get_reserve_units_per_month()
		and first.get_inference_workload_units_per_month()
			== second.get_inference_workload_units_per_month()
		and first.get_training_allocation_units_per_month()
			== second.get_training_allocation_units_per_month()
		and first.get_cumulative_training_compute_unit_months()
			== second.get_cumulative_training_compute_unit_months()
		and first.get_cumulative_served_inference_compute_unit_months()
			== second.get_cumulative_served_inference_compute_unit_months()
		and first.get_cumulative_unmet_inference_compute_unit_months()
			== second.get_cumulative_unmet_inference_compute_unit_months()
	)


static func _reason_delta_matches(
	trace: Array[EffectContributionType],
	index: int,
	reason: StringName,
	delta: int
) -> bool:
	return (
		index >= 0
		and index < trace.size()
		and trace[index].get_reason_key() == reason
		and trace[index].get_delta() == delta
	)


static func _compute_reason_delta_matches(
	trace: Array[EffectContributionType],
	index: int,
	reason: StringName,
	delta: int
) -> bool:
	return (
		_reason_delta_matches(trace, index, reason, delta)
		and trace[index].get_source_key() == EffectContributionType.SOURCE_COMPUTE
		and trace[index].get_subject_key() == EffectContributionType.SUBJECT_COMPANY
		and trace[index].get_unit() == EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
	)


static func _traces_equal(
	first: Array[EffectContributionType],
	second: Array[EffectContributionType]
) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		if (
			first[index].get_source_key() != second[index].get_source_key()
			or first[index].get_reason_key() != second[index].get_reason_key()
			or first[index].get_subject_key() != second[index].get_subject_key()
			or first[index].get_metric_key() != second[index].get_metric_key()
			or first[index].get_unit() != second[index].get_unit()
			or first[index].get_delta() != second[index].get_delta()
		):
			return false
	return true


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
