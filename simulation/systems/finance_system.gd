class_name FinanceSystem
extends RefCounted


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1


## Settles one month atomically using revenue then operating cost explanation order.
## Invalid flow values or a cash boundary failure leave state and effects unchanged.
func settle_month(company_state: CompanyStateType) -> EffectBatchResultType:
	if company_state == null:
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	var cash_before_cents: int = company_state.get_cash_cents()
	var revenue_cents: int = company_state.get_monthly_revenue_cents()
	var operating_cost_cents: int = company_state.get_monthly_operating_cost_cents()
	if revenue_cents < 0 or operating_cost_cents < 0:
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	var cash_delta_cents: int = revenue_cents - operating_cost_cents
	if not _can_add(cash_before_cents, cash_delta_cents):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var cash_after_cents: int = cash_before_cents + cash_delta_cents

	var contributions: Array[EffectContributionType] = []
	if revenue_cents != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_FINANCE,
			EffectContributionType.REASON_MONTHLY_REVENUE,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			revenue_cents
		))
	if operating_cost_cents != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_FINANCE,
			EffectContributionType.REASON_MONTHLY_OPERATING_COST,
			EffectContributionType.SUBJECT_COMPANY,
			EffectContributionType.METRIC_CASH_CENTS,
			EffectContributionType.Unit.CENTS,
			-operating_cost_cents
		))

	company_state._commit_financials(cash_after_cents, revenue_cents)
	return EffectBatchResultType.new(EffectBatchResultType.ErrorCode.NONE, contributions)


func _failed(error_code: EffectBatchResultType.ErrorCode) -> EffectBatchResultType:
	var no_contributions: Array[EffectContributionType] = []
	return EffectBatchResultType.new(error_code, no_contributions)


func _can_add(value: int, delta: int) -> bool:
	if delta > 0:
		return value <= MAX_SIGNED_INT - delta
	if delta < 0:
		return value >= MIN_SIGNED_INT - delta
	return true
