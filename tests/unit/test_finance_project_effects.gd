extends RefCounted


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const FinanceSystemType = preload("res://simulation/systems/finance_system.gd")
const ProjectSystemType = preload("res://simulation/systems/project_system.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1
const GOLDEN_PROJECT_ID: StringName = &"golden_project"


static func run(report: Callable) -> void:
	_test_typed_boundaries_and_ownership(report)
	_test_finance_gross_effects(report)
	_test_finance_zero_and_boundaries(report)
	_test_project_progress_completion_and_no_op(report)
	_test_invalid_and_overflow_atomicity(report)
	_test_golden_case_and_determinism(report)


static func _test_typed_boundaries_and_ownership(report: Callable) -> void:
	var company: CompanyStateType = CompanyStateType.new()
	var project: ProjectStateType = ProjectStateType.new()
	var finance_system: FinanceSystemType = FinanceSystemType.new()
	var project_system: ProjectSystemType = ProjectSystemType.new()
	var contribution: EffectContributionType = EffectContributionType.new(
		EffectContributionType.SOURCE_FINANCE,
		EffectContributionType.REASON_MONTHLY_REVENUE,
		EffectContributionType.SUBJECT_COMPANY,
		EffectContributionType.METRIC_CASH_CENTS,
		EffectContributionType.Unit.CENTS,
		1
	)
	var contributions: Array[EffectContributionType] = [contribution]
	var batch_result: EffectBatchResultType = EffectBatchResultType.new(
		EffectBatchResultType.ErrorCode.NONE,
		contributions
	)
	var failed_batch_result: EffectBatchResultType = EffectBatchResultType.new(
		EffectBatchResultType.ErrorCode.INVALID_STATE,
		contributions
	)
	var first_state: GameStateType = GameStateType.new()
	var second_state: GameStateType = GameStateType.new()

	_report(
		report,
		company is RefCounted
			and project is RefCounted
			and finance_system is RefCounted
			and project_system is RefCounted
			and contribution is RefCounted
			and batch_result is RefCounted,
		"TP-011 production boundaries are typed RefCounted objects"
	)
	_report(
		report,
		first_state.get_clock().get_year() == 2026
			and first_state.get_clock().get_month() == 1
			and first_state.get_clock().get_quarter() == 1,
		"TP-011 default GameState remains January 2026 Q1"
	)
	_report(
		report,
		first_state.get_clock() != second_state.get_clock()
			and first_state.get_company() != second_state.get_company()
			and first_state.get_project() != second_state.get_project(),
		"TP-011 GameState instances own independent clock company and project state"
	)
	var returned_contributions: Array[EffectContributionType] = batch_result.get_contributions()
	returned_contributions.clear()
	_report(
		report,
		batch_result.is_successful()
			and batch_result.get_error_code() == EffectBatchResultType.ErrorCode.NONE
			and batch_result.get_contributions().size() == 1
			and not failed_batch_result.is_successful()
			and failed_batch_result.get_error_code() == EffectBatchResultType.ErrorCode.INVALID_STATE
			and failed_batch_result.get_contributions().is_empty(),
		"TP-011 batch result distinguishes success and protects ordered effects"
	)


static func _test_finance_gross_effects(report: Callable) -> void:
	var company: CompanyStateType = CompanyStateType.new(1_000_000, 120_000, 80_000)
	var finance_system: FinanceSystemType = FinanceSystemType.new()
	var cash_before_cents: int = company.get_cash_cents()
	var result: EffectBatchResultType = finance_system.settle_month(company)
	var effects: Array[EffectContributionType] = result.get_contributions()
	var ordered_gross_effects: bool = (
		_effect_at_matches(
			effects,
			0,
			EffectContributionType.SOURCE_FINANCE,
			EffectContributionType.REASON_MONTHLY_REVENUE,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			120_000
		)
		and _effect_at_matches(
			effects,
			1,
			EffectContributionType.SOURCE_FINANCE,
			EffectContributionType.REASON_MONTHLY_OPERATING_COST,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			-80_000
		)
	)
	_report(
		report,
		result.is_successful()
			and result.get_error_code() == EffectBatchResultType.ErrorCode.NONE
			and company.get_cash_cents() == 1_040_000
			and effects.size() == 2,
		"TP-011 finance settles one month in integer cents"
	)
	_report(report, ordered_gross_effects, "TP-011 finance emits ordered non-zero gross effects")
	_report(
		report,
		cash_before_cents + _sum_metric(effects, EffectContributionType.METRIC_CASH_CENTS)
			== company.get_cash_cents(),
		"TP-011 finance effects reconcile exactly to cash delta"
	)


static func _test_finance_zero_and_boundaries(report: Callable) -> void:
	var finance_system: FinanceSystemType = FinanceSystemType.new()
	var zero_company: CompanyStateType = CompanyStateType.new(50, 0, 0)
	var zero_result: EffectBatchResultType = finance_system.settle_month(zero_company)
	var net_zero_company: CompanyStateType = CompanyStateType.new(50, 25, 25)
	var net_zero_result: EffectBatchResultType = finance_system.settle_month(net_zero_company)
	var boundary_company: CompanyStateType = CompanyStateType.new(
		MIN_SIGNED_INT,
		MAX_SIGNED_INT,
		MAX_SIGNED_INT
	)
	var boundary_result: EffectBatchResultType = finance_system.settle_month(boundary_company)

	_report(
		report,
		zero_result.is_successful()
			and zero_result.get_contributions().is_empty()
			and zero_company.get_cash_cents() == 50,
		"TP-011 zero finance components emit no fake effects"
	)
	_report(
		report,
		net_zero_result.is_successful()
			and net_zero_result.get_contributions().size() == 2
			and net_zero_company.get_cash_cents() == 50
			and _sum_metric(
				net_zero_result.get_contributions(),
				EffectContributionType.METRIC_CASH_CENTS
			) == 0,
		"TP-011 non-zero net-zero finance keeps both gross effects"
	)
	_report(
		report,
		boundary_result.is_successful()
			and boundary_result.get_contributions().size() == 2
			and boundary_company.get_cash_cents() == MIN_SIGNED_INT,
		"TP-011 representable finance boundary remains deterministic"
	)


static func _test_project_progress_completion_and_no_op(report: Callable) -> void:
	var company: CompanyStateType = CompanyStateType.new(500_000, 120_000, 80_000)
	var project: ProjectStateType = ProjectStateType.new(GOLDEN_PROJECT_ID, 3, 25_000, 30_000)
	var project_system: ProjectSystemType = ProjectSystemType.new()
	var start_result: EffectBatchResultType = project_system.start_project(project)
	var cash_before_cents: int = company.get_cash_cents()
	var progress_before_months: int = project.get_progress_months()
	var revenue_before_cents: int = company.get_monthly_revenue_cents()
	var first_result: EffectBatchResultType = project_system.advance_month(company, project)
	var first_effects: Array[EffectContributionType] = first_result.get_contributions()
	var first_effects_ordered: bool = (
		_effect_at_matches(
			first_effects,
			0,
			EffectContributionType.SOURCE_PROJECT,
			EffectContributionType.REASON_PROJECT_MONTHLY_COST,
			GOLDEN_PROJECT_ID,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			-25_000
		)
		and _effect_at_matches(
			first_effects,
			1,
			EffectContributionType.SOURCE_PROJECT,
			EffectContributionType.REASON_PROJECT_PROGRESS,
			GOLDEN_PROJECT_ID,
			EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS,
			EffectContributionType.Unit.MONTHS,
			1
		)
	)
	var first_reconciles: bool = (
		cash_before_cents + _sum_metric(first_effects, EffectContributionType.METRIC_CASH_CENTS)
			== company.get_cash_cents()
		and progress_before_months + _sum_metric(
			first_effects,
			EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS
		) == project.get_progress_months()
		and revenue_before_cents + _sum_metric(
			first_effects,
			EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS
		) == company.get_monthly_revenue_cents()
	)
	_report(
		report,
		start_result.is_successful()
			and start_result.get_contributions().is_empty()
			and project.get_lifecycle() == ProjectStateType.Lifecycle.ACTIVE
			and first_result.is_successful()
			and first_effects.size() == 2
			and first_effects_ordered,
		"TP-011 project starts then advances exactly one charged month"
	)
	_report(report, first_reconciles, "TP-011 project effects reconcile exactly to state deltas")

	var second_cash_before_cents: int = company.get_cash_cents()
	var second_progress_before_months: int = project.get_progress_months()
	var second_revenue_before_cents: int = company.get_monthly_revenue_cents()
	var second_result: EffectBatchResultType = project_system.advance_month(company, project)
	var second_effects: Array[EffectContributionType] = second_result.get_contributions()
	var second_reconciles: bool = _effects_reconcile(
		second_effects,
		second_cash_before_cents,
		company.get_cash_cents(),
		second_progress_before_months,
		project.get_progress_months(),
		second_revenue_before_cents,
		company.get_monthly_revenue_cents()
	)
	var third_cash_before_cents: int = company.get_cash_cents()
	var third_progress_before_months: int = project.get_progress_months()
	var third_revenue_before_cents: int = company.get_monthly_revenue_cents()
	var third_result: EffectBatchResultType = project_system.advance_month(company, project)
	var third_effects: Array[EffectContributionType] = third_result.get_contributions()
	var third_reconciles: bool = _effects_reconcile(
		third_effects,
		third_cash_before_cents,
		company.get_cash_cents(),
		third_progress_before_months,
		project.get_progress_months(),
		third_revenue_before_cents,
		company.get_monthly_revenue_cents()
	)
	var completion_effect_is_ordered: bool = _effect_at_matches(
		third_effects,
		2,
		EffectContributionType.SOURCE_PROJECT,
		EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE,
		GOLDEN_PROJECT_ID,
		EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS,
		EffectContributionType.Unit.CENTS,
		30_000
	)
	_report(
		report,
		second_result.is_successful()
			and third_result.is_successful()
			and second_reconciles
			and third_reconciles
			and project.get_progress_months() == 3
			and project.get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED
			and company.get_cash_cents() == 425_000
			and company.get_monthly_revenue_cents() == 150_000
			and third_effects.size() == 3
			and completion_effect_is_ordered,
		"TP-011 project completes exactly once at required months"
	)

	var completed_cash_cents: int = company.get_cash_cents()
	var completed_revenue_cents: int = company.get_monthly_revenue_cents()
	var completed_progress_months: int = project.get_progress_months()
	var no_op_result: EffectBatchResultType = project_system.advance_month(company, project)
	_report(
		report,
		no_op_result.is_successful()
			and no_op_result.get_contributions().is_empty()
			and company.get_cash_cents() == completed_cash_cents
			and company.get_monthly_revenue_cents() == completed_revenue_cents
			and project.get_progress_months() == completed_progress_months
			and project.get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED,
		"TP-011 completed project remains a stable empty no-op"
	)

	var zero_company: CompanyStateType = CompanyStateType.new()
	var zero_project: ProjectStateType = ProjectStateType.new(&"zero_project", 1, 0, 0)
	var zero_start: EffectBatchResultType = project_system.start_project(zero_project)
	var zero_advance: EffectBatchResultType = project_system.advance_month(zero_company, zero_project)
	_report(
		report,
		zero_start.is_successful()
			and zero_advance.is_successful()
			and zero_advance.get_contributions().size() == 1
			and zero_project.get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED,
		"TP-011 zero project cost and benefit emit only real progress"
	)


static func _test_invalid_and_overflow_atomicity(report: Callable) -> void:
	var finance_system: FinanceSystemType = FinanceSystemType.new()
	var project_system: ProjectSystemType = ProjectSystemType.new()
	var all_atomic: bool = true
	var null_company: CompanyStateType = null
	var null_project: ProjectStateType = null
	all_atomic = all_atomic and _is_failed_empty(
		finance_system.settle_month(null_company),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	all_atomic = all_atomic and _is_failed_empty(
		project_system.start_project(null_project),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	var null_company_project: ProjectStateType = ProjectStateType.new(
		&"null_company_project",
		2,
		7,
		3,
		ProjectStateType.Lifecycle.ACTIVE,
		0
	)
	all_atomic = all_atomic and _is_failed_empty(
		project_system.advance_month(null_company, null_company_project),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	all_atomic = all_atomic and _project_fields_match(
		null_company_project,
		&"null_company_project",
		ProjectStateType.Lifecycle.ACTIVE,
		2,
		0,
		7,
		3
	)
	var null_project_company: CompanyStateType = CompanyStateType.new(200, 10, 5)
	all_atomic = all_atomic and _is_failed_empty(
		project_system.advance_month(null_project_company, null_project),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	all_atomic = all_atomic and _company_fields_match(null_project_company, 200, 10, 5)

	var repeated_start_project: ProjectStateType = ProjectStateType.new(&"repeated_start", 2, 7, 3)
	var first_start_result: EffectBatchResultType = project_system.start_project(repeated_start_project)
	var repeated_start_result: EffectBatchResultType = project_system.start_project(repeated_start_project)
	all_atomic = all_atomic and first_start_result.is_successful()
	all_atomic = all_atomic and _is_failed_empty(
		repeated_start_result,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	all_atomic = all_atomic and _project_fields_match(
		repeated_start_project,
		&"repeated_start",
		ProjectStateType.Lifecycle.ACTIVE,
		2,
		0,
		7,
		3
	)

	var invalid_revenue_company: CompanyStateType = CompanyStateType.new(100, -1, 0)
	var invalid_revenue_result: EffectBatchResultType = finance_system.settle_month(invalid_revenue_company)
	all_atomic = all_atomic and _is_failed_empty(
		invalid_revenue_result,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	all_atomic = all_atomic and _company_fields_match(invalid_revenue_company, 100, -1, 0)

	var invalid_cost_company: CompanyStateType = CompanyStateType.new(100, 0, -1)
	var invalid_cost_result: EffectBatchResultType = finance_system.settle_month(invalid_cost_company)
	all_atomic = all_atomic and _is_failed_empty(
		invalid_cost_result,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	all_atomic = all_atomic and _company_fields_match(invalid_cost_company, 100, 0, -1)

	var cash_overflow_company: CompanyStateType = CompanyStateType.new(MAX_SIGNED_INT, 1, 0)
	var cash_overflow_result: EffectBatchResultType = finance_system.settle_month(cash_overflow_company)
	all_atomic = all_atomic and _is_failed_empty(
		cash_overflow_result,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	)
	all_atomic = all_atomic and _company_fields_match(cash_overflow_company, MAX_SIGNED_INT, 1, 0)

	var cash_underflow_company: CompanyStateType = CompanyStateType.new(MIN_SIGNED_INT, 0, 1)
	var cash_underflow_result: EffectBatchResultType = finance_system.settle_month(cash_underflow_company)
	all_atomic = all_atomic and _is_failed_empty(
		cash_underflow_result,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	)
	all_atomic = all_atomic and _company_fields_match(cash_underflow_company, MIN_SIGNED_INT, 0, 1)

	var invalid_projects: Array[ProjectStateType] = []
	invalid_projects.append(ProjectStateType.new(&"", 1, 0, 0))
	invalid_projects.append(ProjectStateType.new(&"invalid_duration", 0, 0, 0))
	invalid_projects.append(ProjectStateType.new(&"negative_duration", -1, 0, 0))
	invalid_projects.append(ProjectStateType.new(
		&"invalid_progress",
		2,
		0,
		0,
		ProjectStateType.Lifecycle.NOT_STARTED,
		-1
	))
	invalid_projects.append(ProjectStateType.new(
		&"excess_progress",
		2,
		0,
		0,
		ProjectStateType.Lifecycle.NOT_STARTED,
		3
	))
	invalid_projects.append(ProjectStateType.new(
		&"not_started_with_progress",
		2,
		0,
		0,
		ProjectStateType.Lifecycle.NOT_STARTED,
		1
	))
	invalid_projects.append(ProjectStateType.new(
		&"active_at_required",
		2,
		0,
		0,
		ProjectStateType.Lifecycle.ACTIVE,
		2
	))
	invalid_projects.append(ProjectStateType.new(
		&"completed_before_required",
		2,
		0,
		0,
		ProjectStateType.Lifecycle.COMPLETED,
		1
	))
	invalid_projects.append(ProjectStateType.new(
		&"already_active",
		2,
		0,
		0,
		ProjectStateType.Lifecycle.ACTIVE,
		1
	))
	invalid_projects.append(ProjectStateType.new(
		&"already_completed",
		2,
		0,
		0,
		ProjectStateType.Lifecycle.COMPLETED,
		2
	))
	invalid_projects.append(ProjectStateType.new(&"invalid_cost", 1, -1, 0))
	invalid_projects.append(ProjectStateType.new(&"invalid_benefit", 1, 0, -1))
	for invalid_project in invalid_projects:
		var project_id_before: StringName = invalid_project.get_project_id()
		var lifecycle_before: int = invalid_project.get_lifecycle()
		var required_before_months: int = invalid_project.get_required_months()
		var progress_before_months: int = invalid_project.get_progress_months()
		var cost_before_cents: int = invalid_project.get_monthly_cost_cents()
		var benefit_before_cents: int = invalid_project.get_completion_monthly_revenue_delta_cents()
		var invalid_project_result: EffectBatchResultType = project_system.start_project(invalid_project)
		all_atomic = all_atomic and _is_failed_empty(
			invalid_project_result,
			EffectBatchResultType.ErrorCode.INVALID_STATE
		)
		all_atomic = all_atomic and _project_fields_match(
			invalid_project,
			project_id_before,
			lifecycle_before,
			required_before_months,
			progress_before_months,
			cost_before_cents,
			benefit_before_cents
		)

	var not_started_company: CompanyStateType = CompanyStateType.new(200, 10, 5)
	var not_started_project: ProjectStateType = ProjectStateType.new(&"not_started", 2, 7, 3)
	var not_started_result: EffectBatchResultType = project_system.advance_month(
		not_started_company,
		not_started_project
	)
	all_atomic = all_atomic and _is_failed_empty(
		not_started_result,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	)
	all_atomic = all_atomic and _company_fields_match(not_started_company, 200, 10, 5)
	all_atomic = all_atomic and _project_fields_match(
		not_started_project,
		&"not_started",
		ProjectStateType.Lifecycle.NOT_STARTED,
		2,
		0,
		7,
		3
	)

	var underflow_company: CompanyStateType = CompanyStateType.new(MIN_SIGNED_INT, 0, 0)
	var underflow_project: ProjectStateType = ProjectStateType.new(
		&"underflow_project",
		2,
		1,
		0,
		ProjectStateType.Lifecycle.ACTIVE,
		0
	)
	var underflow_result: EffectBatchResultType = project_system.advance_month(
		underflow_company,
		underflow_project
	)
	all_atomic = all_atomic and _is_failed_empty(
		underflow_result,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	)
	all_atomic = all_atomic and _company_fields_match(underflow_company, MIN_SIGNED_INT, 0, 0)
	all_atomic = all_atomic and _project_fields_match(
		underflow_project,
		&"underflow_project",
		ProjectStateType.Lifecycle.ACTIVE,
		2,
		0,
		1,
		0
	)

	var benefit_overflow_company: CompanyStateType = CompanyStateType.new(100, MAX_SIGNED_INT, 0)
	var benefit_overflow_project: ProjectStateType = ProjectStateType.new(
		&"benefit_overflow_project",
		1,
		25,
		1,
		ProjectStateType.Lifecycle.ACTIVE,
		0
	)
	var benefit_overflow_result: EffectBatchResultType = project_system.advance_month(
		benefit_overflow_company,
		benefit_overflow_project
	)
	all_atomic = all_atomic and _is_failed_empty(
		benefit_overflow_result,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	)
	all_atomic = all_atomic and _company_fields_match(
		benefit_overflow_company,
		100,
		MAX_SIGNED_INT,
		0
	)
	all_atomic = all_atomic and _project_fields_match(
		benefit_overflow_project,
		&"benefit_overflow_project",
		ProjectStateType.Lifecycle.ACTIVE,
		1,
		0,
		25,
		1
	)

	_report(report, all_atomic, "TP-011 rejected invalid or overflow step is atomic")


static func _test_golden_case_and_determinism(report: Callable) -> void:
	var first_state: GameStateType = _create_golden_state()
	var second_state: GameStateType = _create_golden_state()
	var first_trace: Array[EffectContributionType] = []
	var second_trace: Array[EffectContributionType] = []
	var first_succeeded: bool = _run_golden_sequence(first_state, first_trace)
	var second_succeeded: bool = _run_golden_sequence(second_state, second_trace)
	var final_fields_match: bool = (
		first_state.get_clock().get_year() == 2026
		and first_state.get_clock().get_month() == 4
		and first_state.get_clock().get_quarter() == 2
		and first_state.get_company().get_cash_cents() == 1_075_000
		and first_state.get_company().get_monthly_revenue_cents() == 150_000
		and first_state.get_company().get_monthly_operating_cost_cents() == 80_000
		and first_state.get_project().get_project_id() == GOLDEN_PROJECT_ID
		and first_state.get_project().get_progress_months() == 3
		and first_state.get_project().get_required_months() == 3
		and first_state.get_project().get_monthly_cost_cents() == 25_000
		and first_state.get_project().get_completion_monthly_revenue_delta_cents() == 30_000
		and first_state.get_project().get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED
	)
	var equivalent_runs_match: bool = (
		first_succeeded
		and second_succeeded
		and _state_fields_equal(first_state, second_state)
		and _traces_equal(first_trace, second_trace)
	)
	var fixed_trace_matches: bool = _trace_matches_golden(first_trace)

	_report(report, final_fields_match, "TP-011 three explicit months reach the fixed Golden fields")
	_report(report, equivalent_runs_match, "TP-011 equivalent typed states produce equal ordered traces")
	_report(
		report,
		first_succeeded and second_succeeded and final_fields_match and equivalent_runs_match and fixed_trace_matches,
		"TP-011 deterministic three-month trace matches golden result"
	)


static func _create_golden_state() -> GameStateType:
	var company: CompanyStateType = CompanyStateType.new(1_000_000, 120_000, 80_000)
	var project: ProjectStateType = ProjectStateType.new(
		GOLDEN_PROJECT_ID,
		3,
		25_000,
		30_000
	)
	return GameStateType.new(company, project)


static func _run_golden_sequence(
	state: GameStateType,
	trace: Array[EffectContributionType]
) -> bool:
	var project_system: ProjectSystemType = ProjectSystemType.new()
	var finance_system: FinanceSystemType = FinanceSystemType.new()
	var start_result: EffectBatchResultType = project_system.start_project(state.get_project())
	var all_succeeded: bool = start_result.is_successful() and start_result.get_contributions().is_empty()
	for _month_index in 3:
		var project_cash_before_cents: int = state.get_company().get_cash_cents()
		var project_progress_before_months: int = state.get_project().get_progress_months()
		var project_revenue_before_cents: int = state.get_company().get_monthly_revenue_cents()
		var project_result: EffectBatchResultType = project_system.advance_month(
			state.get_company(),
			state.get_project()
		)
		var project_effects: Array[EffectContributionType] = project_result.get_contributions()
		all_succeeded = (
			all_succeeded
			and project_result.is_successful()
			and _effects_reconcile(
				project_effects,
				project_cash_before_cents,
				state.get_company().get_cash_cents(),
				project_progress_before_months,
				state.get_project().get_progress_months(),
				project_revenue_before_cents,
				state.get_company().get_monthly_revenue_cents()
			)
		)
		_append_effects(trace, project_effects)
		var finance_cash_before_cents: int = state.get_company().get_cash_cents()
		var finance_revenue_before_cents: int = state.get_company().get_monthly_revenue_cents()
		var finance_result: EffectBatchResultType = finance_system.settle_month(state.get_company())
		var finance_effects: Array[EffectContributionType] = finance_result.get_contributions()
		all_succeeded = (
			all_succeeded
			and finance_result.is_successful()
			and finance_cash_before_cents + _sum_metric(
				finance_effects,
				EffectContributionType.METRIC_CASH_CENTS
			) == state.get_company().get_cash_cents()
			and state.get_company().get_monthly_revenue_cents() == finance_revenue_before_cents
		)
		_append_effects(trace, finance_effects)
		all_succeeded = all_succeeded and state.get_clock().advance_month()
	return all_succeeded


static func _append_effects(
	target: Array[EffectContributionType],
	source: Array[EffectContributionType]
) -> void:
	for effect in source:
		target.append(effect)


static func _is_failed_empty(result: EffectBatchResultType, expected_error_code: int) -> bool:
	return (
		not result.is_successful()
		and result.get_error_code() == expected_error_code
		and result.get_contributions().is_empty()
	)


static func _company_fields_match(
	company: CompanyStateType,
	cash_cents: int,
	monthly_revenue_cents: int,
	monthly_operating_cost_cents: int
) -> bool:
	return (
		company.get_cash_cents() == cash_cents
		and company.get_monthly_revenue_cents() == monthly_revenue_cents
		and company.get_monthly_operating_cost_cents() == monthly_operating_cost_cents
	)


static func _project_fields_match(
	project: ProjectStateType,
	project_id: StringName,
	lifecycle: int,
	required_months: int,
	progress_months: int,
	monthly_cost_cents: int,
	completion_revenue_delta_cents: int
) -> bool:
	return (
		project.get_project_id() == project_id
		and project.get_lifecycle() == lifecycle
		and project.get_required_months() == required_months
		and project.get_progress_months() == progress_months
		and project.get_monthly_cost_cents() == monthly_cost_cents
		and project.get_completion_monthly_revenue_delta_cents()
			== completion_revenue_delta_cents
	)


static func _effects_reconcile(
	effects: Array[EffectContributionType],
	cash_before_cents: int,
	cash_after_cents: int,
	progress_before_months: int,
	progress_after_months: int,
	revenue_before_cents: int,
	revenue_after_cents: int
) -> bool:
	return (
		cash_before_cents + _sum_metric(effects, EffectContributionType.METRIC_CASH_CENTS)
			== cash_after_cents
		and progress_before_months + _sum_metric(
			effects,
			EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS
		) == progress_after_months
		and revenue_before_cents + _sum_metric(
			effects,
			EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS
		) == revenue_after_cents
	)


static func _sum_metric(
	effects: Array[EffectContributionType],
	metric_key: StringName
) -> int:
	var total: int = 0
	for effect in effects:
		if effect.get_metric_key() == metric_key:
			total += effect.get_delta()
	return total


static func _effect_at_matches(
	effects: Array[EffectContributionType],
	index: int,
	source_key: StringName,
	reason_key: StringName,
	subject_key: StringName,
	metric_key: StringName,
	unit: int,
	delta: int
) -> bool:
	if index < 0 or index >= effects.size():
		return false
	var effect: EffectContributionType = effects[index]
	return (
		effect.get_source_key() == source_key
		and effect.get_reason_key() == reason_key
		and effect.get_subject_key() == subject_key
		and effect.get_metric_key() == metric_key
		and effect.get_unit() == unit
		and effect.get_delta() == delta
	)


static func _state_fields_equal(first_state: GameStateType, second_state: GameStateType) -> bool:
	return (
		first_state.get_clock().get_year() == second_state.get_clock().get_year()
		and first_state.get_clock().get_month() == second_state.get_clock().get_month()
		and first_state.get_clock().get_quarter() == second_state.get_clock().get_quarter()
		and first_state.get_company().get_cash_cents() == second_state.get_company().get_cash_cents()
		and first_state.get_company().get_monthly_revenue_cents()
			== second_state.get_company().get_monthly_revenue_cents()
		and first_state.get_company().get_monthly_operating_cost_cents()
			== second_state.get_company().get_monthly_operating_cost_cents()
		and first_state.get_project().get_project_id() == second_state.get_project().get_project_id()
		and first_state.get_project().get_lifecycle() == second_state.get_project().get_lifecycle()
		and first_state.get_project().get_required_months()
			== second_state.get_project().get_required_months()
		and first_state.get_project().get_progress_months()
			== second_state.get_project().get_progress_months()
		and first_state.get_project().get_monthly_cost_cents()
			== second_state.get_project().get_monthly_cost_cents()
		and first_state.get_project().get_completion_monthly_revenue_delta_cents()
			== second_state.get_project().get_completion_monthly_revenue_delta_cents()
	)


static func _traces_equal(
	first_trace: Array[EffectContributionType],
	second_trace: Array[EffectContributionType]
) -> bool:
	if first_trace.size() != second_trace.size():
		return false
	for index in first_trace.size():
		var first_effect: EffectContributionType = first_trace[index]
		var second_effect: EffectContributionType = second_trace[index]
		if first_effect.get_source_key() != second_effect.get_source_key():
			return false
		if first_effect.get_reason_key() != second_effect.get_reason_key():
			return false
		if first_effect.get_subject_key() != second_effect.get_subject_key():
			return false
		if first_effect.get_metric_key() != second_effect.get_metric_key():
			return false
		if first_effect.get_unit() != second_effect.get_unit():
			return false
		if first_effect.get_delta() != second_effect.get_delta():
			return false
	return true


static func _trace_matches_golden(trace: Array[EffectContributionType]) -> bool:
	if trace.size() != 13:
		return false
	var matches: bool = true
	matches = matches and _matches_project_cost(trace, 0)
	matches = matches and _matches_project_progress(trace, 1)
	matches = matches and _matches_finance_revenue(trace, 2, 120_000)
	matches = matches and _matches_finance_cost(trace, 3)
	matches = matches and _matches_project_cost(trace, 4)
	matches = matches and _matches_project_progress(trace, 5)
	matches = matches and _matches_finance_revenue(trace, 6, 120_000)
	matches = matches and _matches_finance_cost(trace, 7)
	matches = matches and _matches_project_cost(trace, 8)
	matches = matches and _matches_project_progress(trace, 9)
	matches = matches and _effect_at_matches(
		trace,
		10,
		EffectContributionType.SOURCE_PROJECT,
		EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE,
		GOLDEN_PROJECT_ID,
		EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS,
		EffectContributionType.Unit.CENTS,
		30_000
	)
	matches = matches and _matches_finance_revenue(trace, 11, 150_000)
	matches = matches and _matches_finance_cost(trace, 12)
	return matches


static func _matches_project_cost(trace: Array[EffectContributionType], index: int) -> bool:
	return _effect_at_matches(
		trace,
		index,
		EffectContributionType.SOURCE_PROJECT,
		EffectContributionType.REASON_PROJECT_MONTHLY_COST,
		GOLDEN_PROJECT_ID,
		EffectContributionType.METRIC_CASH_CENTS,
		EffectContributionType.Unit.CENTS,
		-25_000
	)


static func _matches_project_progress(trace: Array[EffectContributionType], index: int) -> bool:
	return _effect_at_matches(
		trace,
		index,
		EffectContributionType.SOURCE_PROJECT,
		EffectContributionType.REASON_PROJECT_PROGRESS,
		GOLDEN_PROJECT_ID,
		EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS,
		EffectContributionType.Unit.MONTHS,
		1
	)


static func _matches_finance_revenue(
	trace: Array[EffectContributionType],
	index: int,
	revenue_cents: int
) -> bool:
	return _effect_at_matches(
		trace,
		index,
		EffectContributionType.SOURCE_FINANCE,
		EffectContributionType.REASON_MONTHLY_REVENUE,
		EffectContributionType.SUBJECT_COMPANY,
		EffectContributionType.METRIC_CASH_CENTS,
		EffectContributionType.Unit.CENTS,
		revenue_cents
	)


static func _matches_finance_cost(trace: Array[EffectContributionType], index: int) -> bool:
	return _effect_at_matches(
		trace,
		index,
		EffectContributionType.SOURCE_FINANCE,
		EffectContributionType.REASON_MONTHLY_OPERATING_COST,
		EffectContributionType.SUBJECT_COMPANY,
		EffectContributionType.METRIC_CASH_CENTS,
		EffectContributionType.Unit.CENTS,
		-80_000
	)


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
