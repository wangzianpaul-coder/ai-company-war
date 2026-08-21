extends RefCounted


const GameCommandType = preload("res://simulation/commands/game_command.gd")
const StartProjectCommandType = preload("res://simulation/commands/start_project_command.gd")
const AdvanceQuarterCommandType = preload("res://simulation/commands/advance_quarter_command.gd")
const SimulationEngineType = preload("res://simulation/engine/simulation_engine.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const FinanceSystemType = preload("res://simulation/systems/finance_system.gd")
const ProjectSystemType = preload("res://simulation/systems/project_system.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1
const PROJECT_ID: StringName = &"project_alpha"


class UnknownGameCommand:
	extends GameCommand


class CommitObserver:
	extends RefCounted
	var count: int = 0
	var last_view_model: DashboardViewModel

	func capture(view_model: DashboardViewModel) -> void:
		count += 1
		last_view_model = view_model


static func run(report: Callable) -> void:
	_test_full_state_copy(report)
	_test_start_project_engine(report)
	_test_quarter_order_and_result_protection(report)
	_test_all_failure_positions(report)
	_test_game_session_boundary(report)
	_test_dashboard_reconciliation(report)
	_test_equivalent_sessions(report)


static func report_dashboard_scene(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-012 dashboard scene reaches the fixed April 2026 Q2 state"
	)


static func report_dashboard_layout(report: Callable, condition: bool) -> void:
	_report(
		report,
		condition,
		"TP-012 dashboard fits 1280x720 and 1920x1080"
	)


static func _test_full_state_copy(report: Callable) -> void:
	var source: GameStateType = _create_golden_state()
	var source_clock_advanced: bool = source.get_clock().advance_months(5)
	var copied: GameStateType = source.copy()
	var values_preserved: bool = (
		source_clock_advanced
		and copied != null
		and copied.get_clock().get_elapsed_months() == 5
		and _states_equal(source, copied)
	)
	var objects_independent: bool = (
		copied != source
		and copied.get_clock() != source.get_clock()
		and copied.get_company() != source.get_company()
		and copied.get_project() != source.get_project()
	)

	var source_project_started: bool = ProjectSystemType.new().start_project(
		source.get_project()
	).is_successful()
	var source_finance_settled: bool = FinanceSystemType.new().settle_month(
		source.get_company()
	).is_successful()
	var source_clock_changed: bool = source.get_clock().advance_month()
	var copy_unchanged: bool = (
		copied.get_clock().get_elapsed_months() == 5
		and copied.get_company().get_cash_cents() == 1_000_000
		and copied.get_project().get_lifecycle() == ProjectStateType.Lifecycle.NOT_STARTED
	)

	var copied_project_started: bool = ProjectSystemType.new().start_project(
		copied.get_project()
	).is_successful()
	var copied_project_advanced: bool = ProjectSystemType.new().advance_month(
		copied.get_company(),
		copied.get_project()
	).is_successful()
	var copied_clock_changed: bool = copied.get_clock().advance_months(2)
	var source_unchanged_by_copy: bool = (
		source.get_clock().get_elapsed_months() == 6
		and source.get_company().get_cash_cents() == 1_040_000
		and source.get_project().get_progress_months() == 0
	)
	_report(
		report,
		values_preserved
			and objects_independent
			and source_project_started
			and source_finance_settled
			and source_clock_changed
			and copy_unchanged
			and copied_project_started
			and copied_project_advanced
			and copied_clock_changed
			and source_unchanged_by_copy,
		"TP-012 full state copy preserves every field with bidirectional isolation"
	)


static func _test_start_project_engine(report: Callable) -> void:
	var source: GameStateType = _create_golden_state()
	var engine: SimulationEngineType = SimulationEngineType.new()
	var result: TickResultType = engine.start_project(source)
	var resulting_state: GameStateType = result.get_state_snapshot()
	var source_unchanged: bool = (
		source.get_clock().get_elapsed_months() == 0
		and source.get_company().get_cash_cents() == 1_000_000
		and source.get_company().get_monthly_revenue_cents() == 120_000
		and source.get_company().get_monthly_operating_cost_cents() == 80_000
		and source.get_project().get_lifecycle() == ProjectStateType.Lifecycle.NOT_STARTED
		and source.get_project().get_progress_months() == 0
	)
	var result_is_start_only: bool = (
		result.is_successful()
		and resulting_state != null
		and result.get_contributions().is_empty()
		and resulting_state.get_clock().get_elapsed_months() == 0
		and resulting_state.get_company().get_cash_cents() == 1_000_000
		and resulting_state.get_project().get_lifecycle() == ProjectStateType.Lifecycle.ACTIVE
		and resulting_state.get_project().get_progress_months() == 0
	)
	_report(
		report,
		source_unchanged and result_is_start_only,
		"TP-012 start project changes only the independent project lifecycle"
	)


static func _test_quarter_order_and_result_protection(report: Callable) -> void:
	var engine: SimulationEngineType = SimulationEngineType.new()
	var start_result: TickResultType = engine.start_project(_create_golden_state())
	var active_state: GameStateType = start_result.get_state_snapshot()
	var active_before: GameStateType = active_state.copy()
	var quarter_result: TickResultType = engine.advance_quarter(active_state)
	var final_state: GameStateType = quarter_result.get_state_snapshot()
	var effects: Array[EffectContributionType] = quarter_result.get_contributions()
	var golden_result: bool = (
		quarter_result.is_successful()
		and final_state != null
		and final_state.get_clock().get_elapsed_months() == 3
		and final_state.get_clock().get_year() == 2026
		and final_state.get_clock().get_month() == 4
		and final_state.get_clock().get_quarter() == 2
		and final_state.get_company().get_cash_cents() == 1_075_000
		and final_state.get_company().get_monthly_revenue_cents() == 150_000
		and final_state.get_company().get_monthly_operating_cost_cents() == 80_000
		and final_state.get_project().get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED
		and final_state.get_project().get_progress_months() == 3
		and effects.size() == 13
		and _trace_matches_golden(effects)
		and _states_equal(active_state, active_before)
	)
	effects.clear()
	var protected_effects: bool = quarter_result.get_contributions().size() == 13
	var changed_snapshot: GameStateType = quarter_result.get_state_snapshot()
	var snapshot_changed: bool = changed_snapshot.get_clock().advance_month()
	var protected_state: GameStateType = quarter_result.get_state_snapshot()
	var result_protected: bool = (
		protected_effects
		and snapshot_changed
		and protected_state.get_clock().get_elapsed_months() == 3
	)
	_report(
		report,
		golden_result and result_protected,
		"TP-012 quarter commits exactly three ordered Project Finance Clock months"
	)


static func _test_all_failure_positions(report: Callable) -> void:
	var engine: SimulationEngineType = SimulationEngineType.new()
	var all_atomic: bool = true
	for failure_month in range(1, 4):
		var project_state: GameStateType = _create_active_state(
			MIN_SIGNED_INT + failure_month - 1,
			0,
			0,
			1
		)
		var project_atomic: bool = _failed_quarter_is_atomic(engine, project_state)
		all_atomic = project_atomic and all_atomic

		var finance_state: GameStateType = _create_active_state(
			MAX_SIGNED_INT - failure_month + 1,
			1,
			0,
			0
		)
		var finance_atomic: bool = _failed_quarter_is_atomic(engine, finance_state)
		all_atomic = finance_atomic and all_atomic

		var clock_state: GameStateType = _create_active_state(0, 0, 0, 0)
		var clock_positioned: bool = clock_state.get_clock().advance_months(
			MAX_SIGNED_INT - failure_month + 1
		)
		var clock_atomic: bool = _failed_quarter_is_atomic(engine, clock_state)
		all_atomic = clock_positioned and clock_atomic and all_atomic
	_report(
		report,
		all_atomic,
		"TP-012 rejected quarter preserves active state and effects atomically"
	)


static func _test_game_session_boundary(report: Callable) -> void:
	var source: GameStateType = _create_golden_state()
	var session: GameSessionType = GameSessionType.new(source)
	var observer: CommitObserver = CommitObserver.new()
	session.committed_result.connect(Callable(observer, "capture"))
	var initial_view_model: DashboardViewModelType = session.get_current_view_model()
	var source_clock_changed: bool = source.get_clock().advance_month()
	var source_project_changed: bool = ProjectSystemType.new().start_project(
		source.get_project()
	).is_successful()
	var source_finance_changed: bool = FinanceSystemType.new().settle_month(
		source.get_company()
	).is_successful()
	var owned_initial: GameStateType = session.get_state_snapshot()
	var constructor_isolated: bool = (
		source_clock_changed
		and source_project_changed
		and source_finance_changed
		and owned_initial.get_clock().get_elapsed_months() == 0
		and owned_initial.get_company().get_cash_cents() == 1_000_000
		and owned_initial.get_project().get_lifecycle() == ProjectStateType.Lifecycle.NOT_STARTED
	)

	var null_command: GameCommandType = null
	var null_rejected: bool = not session.submit_command(null_command).is_successful()
	var base_rejected: bool = not session.submit_command(GameCommandType.new()).is_successful()
	var unknown_rejected: bool = not session.submit_command(UnknownGameCommand.new()).is_successful()
	var early_quarter_rejected: bool = not session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	var rejects_preserved: bool = (
		observer.count == 0
		and session.get_current_view_model() == initial_view_model
		and session.get_last_committed_contributions().is_empty()
		and _states_equal(session.get_state_snapshot(), owned_initial)
	)

	var start_succeeded: bool = session.submit_command(StartProjectCommandType.new()).is_successful()
	var active_snapshot: GameStateType = session.get_state_snapshot()
	var start_view_model: DashboardViewModelType = session.get_current_view_model()
	var repeated_start_rejected: bool = not session.submit_command(
		StartProjectCommandType.new()
	).is_successful()
	var repeated_start_preserved: bool = (
		observer.count == 1
		and session.get_current_view_model() == start_view_model
		and session.get_last_committed_contributions().is_empty()
		and active_snapshot.get_project().get_lifecycle() == ProjectStateType.Lifecycle.ACTIVE
		and _states_equal(session.get_state_snapshot(), active_snapshot)
	)

	var quarter_succeeded: bool = session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	var committed_snapshot: GameStateType = session.get_state_snapshot()
	var returned_effects: Array[EffectContributionType] = session.get_last_committed_contributions()
	returned_effects.clear()
	var returned_snapshot: GameStateType = session.get_state_snapshot()
	var returned_snapshot_changed: bool = returned_snapshot.get_clock().advance_month()
	var access_is_protected: bool = (
		returned_snapshot_changed
		and session.get_last_committed_contributions().size() == 13
		and session.get_state_snapshot().get_clock().get_elapsed_months() == 3
	)

	var boundary_company: CompanyStateType = CompanyStateType.new(MAX_SIGNED_INT - 3, 1, 0)
	var boundary_project: ProjectStateType = ProjectStateType.new(PROJECT_ID, 3, 0, 0)
	var boundary_session: GameSessionType = GameSessionType.new(
		GameStateType.new(boundary_company, boundary_project)
	)
	var boundary_observer: CommitObserver = CommitObserver.new()
	boundary_session.committed_result.connect(Callable(boundary_observer, "capture"))
	var boundary_started: bool = boundary_session.submit_command(
		StartProjectCommandType.new()
	).is_successful()
	var boundary_quarter: bool = boundary_session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	var before_failed_state: GameStateType = boundary_session.get_state_snapshot()
	var before_failed_effects: Array[EffectContributionType] = (
		boundary_session.get_last_committed_contributions()
	)
	var before_failed_view_model: DashboardViewModelType = (
		boundary_session.get_current_view_model()
	)
	var failed_after_commit: bool = not boundary_session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	var failed_commit_preserved: bool = (
		boundary_started
		and boundary_quarter
		and failed_after_commit
		and boundary_observer.count == 2
		and _states_equal(boundary_session.get_state_snapshot(), before_failed_state)
		and _traces_equal(
			boundary_session.get_last_committed_contributions(),
			before_failed_effects
		)
		and boundary_session.get_current_view_model() == before_failed_view_model
	)

	var aggregate_company: CompanyStateType = CompanyStateType.new(
		MIN_SIGNED_INT,
		4_000_000_000_000_000_000,
		0
	)
	var aggregate_project: ProjectStateType = ProjectStateType.new(PROJECT_ID, 3, 0, 0)
	var aggregate_session: GameSessionType = GameSessionType.new(
		GameStateType.new(aggregate_company, aggregate_project)
	)
	var aggregate_observer: CommitObserver = CommitObserver.new()
	aggregate_session.committed_result.connect(Callable(aggregate_observer, "capture"))
	var min_cash_formatted: bool = (
		aggregate_session.get_current_view_model().get_cash_text()
			== "Cash: -9,223,372,036,854,775,808 cents"
	)
	var aggregate_started: bool = aggregate_session.submit_command(
		StartProjectCommandType.new()
	).is_successful()
	var before_aggregate_state: GameStateType = aggregate_session.get_state_snapshot()
	var before_aggregate_view_model: DashboardViewModelType = (
		aggregate_session.get_current_view_model()
	)
	var aggregate_rejected: bool = not aggregate_session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	var aggregate_overflow_preserved: bool = (
		min_cash_formatted
		and aggregate_started
		and aggregate_rejected
		and aggregate_observer.count == 1
		and _states_equal(aggregate_session.get_state_snapshot(), before_aggregate_state)
		and aggregate_session.get_last_committed_contributions().is_empty()
		and aggregate_session.get_current_view_model() == before_aggregate_view_model
	)

	_report(
		report,
		constructor_isolated
			and null_rejected
			and base_rejected
			and unknown_rejected
			and early_quarter_rejected
			and rejects_preserved
			and start_succeeded
			and repeated_start_rejected
			and repeated_start_preserved
			and quarter_succeeded
			and observer.count == 2
			and observer.last_view_model == session.get_current_view_model()
			and committed_snapshot.get_company().get_cash_cents() == 1_075_000
			and access_is_protected
			and failed_commit_preserved
			and aggregate_overflow_preserved,
		"TP-012 GameSession accepts only typed start and quarter commands"
	)


static func _test_dashboard_reconciliation(report: Callable) -> void:
	var session: GameSessionType = GameSessionType.new(_create_golden_state())
	var initial_view_model: DashboardViewModelType = session.get_current_view_model()
	var initial_exact: bool = (
		initial_view_model.get_title_text() == "AI COMPANY WAR"
		and initial_view_model.get_date_text() == "2026 Q1"
		and initial_view_model.get_cash_text() == "Cash: 1,000,000 cents"
		and initial_view_model.get_monthly_revenue_text()
			== "Monthly revenue: 120,000 cents"
		and initial_view_model.get_monthly_operating_cost_text()
			== "Monthly operating cost: 80,000 cents"
		and initial_view_model.get_project_text()
			== "Project: project_alpha — NOT STARTED 0/3"
		and initial_view_model.get_action_text() == "START PROJECT"
		and initial_view_model.is_start_project_available()
	)
	var started: bool = session.submit_command(StartProjectCommandType.new()).is_successful()
	var start_view_model: DashboardViewModelType = session.get_current_view_model()
	var start_exact: bool = (
		started
		and start_view_model.get_date_text() == "2026 Q1"
		and start_view_model.get_cash_text() == "Cash: 1,000,000 cents"
		and start_view_model.get_project_text() == "Project: project_alpha — ACTIVE 0/3"
		and start_view_model.get_action_text() == "NEXT QUARTER"
		and not start_view_model.is_start_project_available()
	)
	var advanced: bool = session.submit_command(AdvanceQuarterCommandType.new()).is_successful()
	var view_model: DashboardViewModelType = session.get_current_view_model()
	var effects: Array[EffectContributionType] = session.get_last_committed_contributions()
	var contribution_totals_match: bool = (
		_sum_reason(effects, EffectContributionType.REASON_MONTHLY_REVENUE) == 390_000
		and _sum_reason(effects, EffectContributionType.REASON_MONTHLY_OPERATING_COST)
			== -240_000
		and _sum_reason(effects, EffectContributionType.REASON_PROJECT_MONTHLY_COST)
			== -75_000
		and _sum_reason(effects, EffectContributionType.REASON_PROJECT_PROGRESS) == 3
		and _sum_reason(effects, EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE)
			== 30_000
	)
	var display_exact: bool = (
		advanced
		and view_model.get_date_text() == "2026 Q2"
		and view_model.get_cash_text() == "Cash: 1,075,000 cents"
		and view_model.get_monthly_revenue_text() == "Monthly revenue: 150,000 cents"
		and view_model.get_monthly_operating_cost_text()
			== "Monthly operating cost: 80,000 cents"
		and view_model.get_project_text() == "Project: project_alpha — COMPLETED 3/3"
		and view_model.get_cash_explanation_text()
			== "Cash: 1,000,000 → 1,075,000 = +75,000 cents"
		and view_model.get_revenue_contributions_text()
			== "Revenue cash contributions: +390,000 cents"
		and view_model.get_operating_cost_contributions_text()
			== "Operating-cost contributions: -240,000 cents"
		and view_model.get_project_cost_contributions_text()
			== "Project-cost contributions: -75,000 cents"
		and view_model.get_progress_contributions_text() == "Project progress: +3 months"
		and view_model.get_completion_revenue_text()
			== "Completion monthly revenue: +30,000 cents"
	)
	_report(
		report,
		initial_exact and start_exact and contribution_totals_match and display_exact,
		"TP-012 dashboard explanation reconciles to committed contributions"
	)


static func _test_equivalent_sessions(report: Callable) -> void:
	var first: GameSessionType = GameSessionType.new(_create_golden_state())
	var second: GameSessionType = GameSessionType.new(_create_golden_state())
	var both_started: bool = (
		first.submit_command(StartProjectCommandType.new()).is_successful()
		and second.submit_command(StartProjectCommandType.new()).is_successful()
	)
	var both_advanced: bool = (
		first.submit_command(AdvanceQuarterCommandType.new()).is_successful()
		and second.submit_command(AdvanceQuarterCommandType.new()).is_successful()
	)
	_report(
		report,
		both_started
			and both_advanced
			and _states_equal(first.get_state_snapshot(), second.get_state_snapshot())
			and _traces_equal(
				first.get_last_committed_contributions(),
				second.get_last_committed_contributions()
			)
			and _view_models_equal(
				first.get_current_view_model(),
				second.get_current_view_model()
			),
		"TP-012 equivalent sessions remain deterministic"
	)


static func _failed_quarter_is_atomic(
	engine: SimulationEngineType,
	state: GameStateType
) -> bool:
	var before: GameStateType = state.copy()
	var result: TickResultType = engine.advance_quarter(state)
	return (
		before != null
		and not result.is_successful()
		and result.get_state_snapshot() == null
		and result.get_contributions().is_empty()
		and _states_equal(state, before)
	)


static func _create_golden_state() -> GameStateType:
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		ProjectStateType.new(PROJECT_ID, 3, 25_000, 30_000)
	)


static func _create_active_state(
	cash_cents: int,
	monthly_revenue_cents: int,
	monthly_operating_cost_cents: int,
	project_monthly_cost_cents: int
) -> GameStateType:
	return GameStateType.new(
		CompanyStateType.new(
			cash_cents,
			monthly_revenue_cents,
			monthly_operating_cost_cents
		),
		ProjectStateType.new(
			PROJECT_ID,
			4,
			project_monthly_cost_cents,
			0,
			ProjectStateType.Lifecycle.ACTIVE,
			0
		)
	)


static func _states_equal(first: GameStateType, second: GameStateType) -> bool:
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
	)


static func _traces_equal(
	first: Array[EffectContributionType],
	second: Array[EffectContributionType]
) -> bool:
	if first.size() != second.size():
		return false
	for index in first.size():
		if not _effects_equal(first[index], second[index]):
			return false
	return true


static func _effects_equal(
	first: EffectContributionType,
	second: EffectContributionType
) -> bool:
	return (
		first.get_source_key() == second.get_source_key()
		and first.get_reason_key() == second.get_reason_key()
		and first.get_subject_key() == second.get_subject_key()
		and first.get_metric_key() == second.get_metric_key()
		and first.get_unit() == second.get_unit()
		and first.get_delta() == second.get_delta()
	)


static func _trace_matches_golden(trace: Array[EffectContributionType]) -> bool:
	if trace.size() != 13:
		return false
	return (
		_effect_matches(trace[0], EffectContributionType.REASON_PROJECT_MONTHLY_COST, -25_000)
		and _effect_matches(trace[1], EffectContributionType.REASON_PROJECT_PROGRESS, 1)
		and _effect_matches(trace[2], EffectContributionType.REASON_MONTHLY_REVENUE, 120_000)
		and _effect_matches(trace[3], EffectContributionType.REASON_MONTHLY_OPERATING_COST, -80_000)
		and _effect_matches(trace[4], EffectContributionType.REASON_PROJECT_MONTHLY_COST, -25_000)
		and _effect_matches(trace[5], EffectContributionType.REASON_PROJECT_PROGRESS, 1)
		and _effect_matches(trace[6], EffectContributionType.REASON_MONTHLY_REVENUE, 120_000)
		and _effect_matches(trace[7], EffectContributionType.REASON_MONTHLY_OPERATING_COST, -80_000)
		and _effect_matches(trace[8], EffectContributionType.REASON_PROJECT_MONTHLY_COST, -25_000)
		and _effect_matches(trace[9], EffectContributionType.REASON_PROJECT_PROGRESS, 1)
		and _effect_matches(
			trace[10],
			EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE,
			30_000
		)
		and _effect_matches(trace[11], EffectContributionType.REASON_MONTHLY_REVENUE, 150_000)
		and _effect_matches(trace[12], EffectContributionType.REASON_MONTHLY_OPERATING_COST, -80_000)
	)


static func _effect_matches(
	effect: EffectContributionType,
	reason_key: StringName,
	delta: int
) -> bool:
	var expected_source: StringName
	var expected_subject: StringName
	var expected_metric: StringName
	var expected_unit: int
	match reason_key:
		EffectContributionType.REASON_MONTHLY_REVENUE:
			expected_source = EffectContributionType.SOURCE_FINANCE
			expected_subject = EffectContributionType.SUBJECT_COMPANY
			expected_metric = EffectContributionType.METRIC_CASH_CENTS
			expected_unit = EffectContributionType.Unit.CENTS
		EffectContributionType.REASON_MONTHLY_OPERATING_COST:
			expected_source = EffectContributionType.SOURCE_FINANCE
			expected_subject = EffectContributionType.SUBJECT_COMPANY
			expected_metric = EffectContributionType.METRIC_CASH_CENTS
			expected_unit = EffectContributionType.Unit.CENTS
		EffectContributionType.REASON_PROJECT_MONTHLY_COST:
			expected_source = EffectContributionType.SOURCE_PROJECT
			expected_subject = PROJECT_ID
			expected_metric = EffectContributionType.METRIC_CASH_CENTS
			expected_unit = EffectContributionType.Unit.CENTS
		EffectContributionType.REASON_PROJECT_PROGRESS:
			expected_source = EffectContributionType.SOURCE_PROJECT
			expected_subject = PROJECT_ID
			expected_metric = EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS
			expected_unit = EffectContributionType.Unit.MONTHS
		EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE:
			expected_source = EffectContributionType.SOURCE_PROJECT
			expected_subject = PROJECT_ID
			expected_metric = EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS
			expected_unit = EffectContributionType.Unit.CENTS
		_:
			return false
	return (
		effect.get_source_key() == expected_source
		and effect.get_reason_key() == reason_key
		and effect.get_subject_key() == expected_subject
		and effect.get_metric_key() == expected_metric
		and effect.get_unit() == expected_unit
		and effect.get_delta() == delta
	)


static func _sum_reason(
	effects: Array[EffectContributionType],
	reason_key: StringName
) -> int:
	var total: int = 0
	for effect in effects:
		if effect.get_reason_key() == reason_key:
			total += effect.get_delta()
	return total


static func _view_models_equal(
	first: DashboardViewModelType,
	second: DashboardViewModelType
) -> bool:
	return (
		first.get_title_text() == second.get_title_text()
		and first.get_date_text() == second.get_date_text()
		and first.get_cash_text() == second.get_cash_text()
		and first.get_monthly_revenue_text() == second.get_monthly_revenue_text()
		and first.get_monthly_operating_cost_text()
			== second.get_monthly_operating_cost_text()
		and first.get_project_text() == second.get_project_text()
		and first.get_action_text() == second.get_action_text()
		and first.is_start_project_available() == second.is_start_project_available()
		and first.get_cash_explanation_text() == second.get_cash_explanation_text()
		and first.get_revenue_contributions_text()
			== second.get_revenue_contributions_text()
		and first.get_operating_cost_contributions_text()
			== second.get_operating_cost_contributions_text()
		and first.get_project_cost_contributions_text()
			== second.get_project_cost_contributions_text()
		and first.get_progress_contributions_text()
			== second.get_progress_contributions_text()
		and first.get_completion_revenue_text() == second.get_completion_revenue_text()
	)


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
