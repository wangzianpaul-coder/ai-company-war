class_name ProjectSystem
extends RefCounted


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1


## Validates and starts the one project slot without advancing a month.
func start_project(project_state: ProjectStateType) -> EffectBatchResultType:
	if not _is_project_valid(project_state):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
	if project_state.get_lifecycle() != ProjectStateType.Lifecycle.NOT_STARTED:
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	project_state._commit_started()
	var no_contributions: Array[EffectContributionType] = []
	return EffectBatchResultType.new(EffectBatchResultType.ErrorCode.NONE, no_contributions)


## Advances at most one active month in cost, progress, completion-benefit order.
## Every resulting value is checked before either state object is changed.
func advance_month(
	company_state: CompanyStateType,
	project_state: ProjectStateType
) -> EffectBatchResultType:
	if not _is_company_valid(company_state) or not _is_project_valid(project_state):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
	if project_state.get_lifecycle() == ProjectStateType.Lifecycle.COMPLETED:
		var completed_no_contributions: Array[EffectContributionType] = []
		return EffectBatchResultType.new(EffectBatchResultType.ErrorCode.NONE, completed_no_contributions)
	if project_state.get_lifecycle() != ProjectStateType.Lifecycle.ACTIVE:
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	var project_cost_cents: int = project_state.get_monthly_cost_cents()
	var cash_before_cents: int = company_state.get_cash_cents()
	var cash_delta_cents: int = -project_cost_cents
	if not _can_add(cash_before_cents, cash_delta_cents):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var cash_after_cents: int = cash_before_cents + cash_delta_cents

	var progress_after_months: int = project_state.get_progress_months() + 1
	var is_completed: bool = progress_after_months == project_state.get_required_months()
	var revenue_before_cents: int = company_state.get_monthly_revenue_cents()
	var revenue_after_cents: int = revenue_before_cents
	var completion_revenue_delta_cents: int = 0
	if is_completed:
		completion_revenue_delta_cents = project_state.get_completion_monthly_revenue_delta_cents()
		if not _can_add(revenue_before_cents, completion_revenue_delta_cents):
			return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
		revenue_after_cents = revenue_before_cents + completion_revenue_delta_cents

	var project_id: StringName = project_state.get_project_id()
	var contributions: Array[EffectContributionType] = []
	if project_cost_cents != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_PROJECT,
			EffectContributionType.REASON_PROJECT_MONTHLY_COST,
			project_id,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			cash_delta_cents
		))
	contributions.append(EffectContributionType.new(
		EffectContributionType.SOURCE_PROJECT,
		EffectContributionType.REASON_PROJECT_PROGRESS,
		project_id,
		EffectContributionType.METRIC_PROJECT_PROGRESS_MONTHS,
		EffectContributionType.Unit.MONTHS,
		1
	))
	if completion_revenue_delta_cents != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_PROJECT,
			EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE,
			project_id,
			EffectContributionType.METRIC_MONTHLY_REVENUE_CENTS,
			EffectContributionType.Unit.CENTS,
			completion_revenue_delta_cents
		))

	company_state._commit_financials(cash_after_cents, revenue_after_cents)
	project_state._commit_advanced(progress_after_months, is_completed)
	return EffectBatchResultType.new(EffectBatchResultType.ErrorCode.NONE, contributions)


func _failed(error_code: EffectBatchResultType.ErrorCode) -> EffectBatchResultType:
	var no_contributions: Array[EffectContributionType] = []
	return EffectBatchResultType.new(error_code, no_contributions)


func _is_company_valid(company_state: CompanyStateType) -> bool:
	return (
		company_state != null
		and company_state.get_monthly_revenue_cents() >= 0
		and company_state.get_monthly_operating_cost_cents() >= 0
	)


func _is_project_valid(project_state: ProjectStateType) -> bool:
	if project_state == null:
		return false
	if project_state.get_project_id() == &"":
		return false
	if project_state.get_required_months() <= 0:
		return false
	if project_state.get_progress_months() < 0:
		return false
	if project_state.get_progress_months() > project_state.get_required_months():
		return false
	if project_state.get_monthly_cost_cents() < 0:
		return false
	if project_state.get_completion_monthly_revenue_delta_cents() < 0:
		return false

	match project_state.get_lifecycle():
		ProjectStateType.Lifecycle.NOT_STARTED:
			return project_state.get_progress_months() == 0
		ProjectStateType.Lifecycle.ACTIVE:
			return project_state.get_progress_months() < project_state.get_required_months()
		ProjectStateType.Lifecycle.COMPLETED:
			return project_state.get_progress_months() == project_state.get_required_months()
	return false


func _can_add(value: int, delta: int) -> bool:
	if delta > 0:
		return value <= MAX_SIGNED_INT - delta
	if delta < 0:
		return value >= MIN_SIGNED_INT - delta
	return true
