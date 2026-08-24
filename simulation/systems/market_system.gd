class_name MarketSystem
extends RefCounted


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const MIN_SIGNED_INT: int = -9_223_372_036_854_775_807 - 1
const TOTAL_BASIS_POINTS: int = 10_000
@warning_ignore("integer_division")
const MAX_WORKLOAD_FOR_BASIS_POINT_CONVERSION: int = MAX_SIGNED_INT / TOTAL_BASIS_POINTS


## Settles both fixed markets and Company recurring revenue as one atomic month.
## Every invariant, calculation and contribution is complete before either state mutates.
func settle_month(
	company_state: CompanyStateType,
	compute_state: ComputeStateType,
	market_state: MarketStateType,
	opponent_compute_state: ComputeStateType = null
) -> EffectBatchResultType:
	if not _is_company_state_valid(company_state) or not _is_compute_state_valid(compute_state):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
	if market_state == null:
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
	if _is_zero_market_state(market_state):
		if opponent_compute_state != null:
			return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
		var no_market_contributions: Array[EffectContributionType] = []
		return EffectBatchResultType.new(
			EffectBatchResultType.ErrorCode.NONE,
			no_market_contributions
		)
	var validation_error: EffectBatchResultType.ErrorCode = _validate_market_state(
		company_state,
		compute_state,
		market_state
	)
	if validation_error != EffectBatchResultType.ErrorCode.NONE:
		return _failed(validation_error)

	var compute_served: int = compute_state.get_served_inference_units_per_month()
	var compute_unmet: int = compute_state.get_unmet_inference_units_per_month()
	if not _can_add_non_negative(compute_served, compute_unmet):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	if (
		compute_served + compute_unmet
		!= compute_state.get_inference_workload_units_per_month()
	):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	var consumer_workload: int = market_state.get_consumer_workload_units_per_month()
	var developer_api_workload: int = (
		market_state.get_developer_api_workload_units_per_month()
	)
	if not _can_add_non_negative(consumer_workload, developer_api_workload):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var total_market_workload: int = consumer_workload + developer_api_workload

	var opponent_consumer_served: int = 0
	var opponent_developer_api_served: int = 0
	if opponent_compute_state == null:
		if (
			market_state.get_consumer_opponent_pressure_bps_per_served_unit() != 0
			or market_state.get_developer_api_opponent_pressure_bps_per_served_unit() != 0
		):
			return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
	else:
		if not _is_compute_state_valid(opponent_compute_state):
			return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
		if (
			opponent_compute_state.get_inference_workload_units_per_month()
			!= total_market_workload
		):
			return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
		var opponent_served: int = (
			opponent_compute_state.get_served_inference_units_per_month()
		)
		var opponent_unmet: int = (
			opponent_compute_state.get_unmet_inference_units_per_month()
		)
		if (
			not _can_add_non_negative(opponent_served, opponent_unmet)
			or opponent_served + opponent_unmet != total_market_workload
		):
			return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)
		opponent_consumer_served = _floor_by_basis_points(
			opponent_served,
			market_state.get_consumer_service_allocation_bps()
		)
		if opponent_consumer_served < 0:
			return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
		opponent_consumer_served = mini(opponent_consumer_served, consumer_workload)
		if not _can_subtract(opponent_served, opponent_consumer_served):
			return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
		opponent_developer_api_served = mini(
			opponent_served - opponent_consumer_served,
			developer_api_workload
		)
		if (
			not _can_add_non_negative(
				opponent_consumer_served,
				opponent_developer_api_served
			)
			or opponent_consumer_served + opponent_developer_api_served
				!= opponent_served
		):
			return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	var consumer_served: int = _floor_by_basis_points(
		compute_served,
		market_state.get_consumer_service_allocation_bps()
	)
	if consumer_served < 0:
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	consumer_served = mini(
		consumer_served,
		market_state.get_consumer_workload_units_per_month()
	)
	if not _can_subtract(compute_served, consumer_served):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var developer_api_served: int = mini(
		compute_served - consumer_served,
		market_state.get_developer_api_workload_units_per_month()
	)
	if not _can_add_non_negative(consumer_served, developer_api_served):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	if consumer_served + developer_api_served != compute_served:
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	if (
		not _can_subtract(consumer_workload, consumer_served)
		or not _can_subtract(developer_api_workload, developer_api_served)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var consumer_unmet: int = consumer_workload - consumer_served
	var developer_api_unmet: int = developer_api_workload - developer_api_served

	var consumer_organic_share_delta: int = (
		market_state.get_consumer_full_service_growth_bps()
	)
	if consumer_unmet != 0:
		var consumer_penalty: int = market_state.get_consumer_unmet_penalty_bps_per_unit()
		if not _can_multiply_non_negative(consumer_unmet, consumer_penalty):
			return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
		consumer_organic_share_delta = -(consumer_unmet * consumer_penalty)
	var developer_api_organic_share_delta: int = (
		market_state.get_developer_api_full_service_growth_bps()
	)
	if developer_api_unmet != 0:
		var developer_api_penalty: int = (
			market_state.get_developer_api_unmet_penalty_bps_per_unit()
		)
		if not _can_multiply_non_negative(developer_api_unmet, developer_api_penalty):
			return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
		developer_api_organic_share_delta = -(developer_api_unmet * developer_api_penalty)

	var consumer_share_before: int = market_state.get_consumer_player_share_bps()
	var developer_api_share_before: int = market_state.get_developer_api_player_share_bps()
	if (
		not _can_add(consumer_share_before, consumer_organic_share_delta)
		or not _can_add(
			developer_api_share_before,
			developer_api_organic_share_delta
		)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var consumer_share_after_organic: int = clampi(
		consumer_share_before + consumer_organic_share_delta,
		0,
		TOTAL_BASIS_POINTS
	)
	var developer_api_share_after_organic: int = clampi(
		developer_api_share_before + developer_api_organic_share_delta,
		0,
		TOTAL_BASIS_POINTS
	)
	if (
		not _can_subtract(consumer_share_after_organic, consumer_share_before)
		or not _can_subtract(
			developer_api_share_after_organic,
			developer_api_share_before
		)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	consumer_organic_share_delta = consumer_share_after_organic - consumer_share_before
	developer_api_organic_share_delta = (
		developer_api_share_after_organic - developer_api_share_before
	)

	var consumer_pressure_rate: int = (
		market_state.get_consumer_opponent_pressure_bps_per_served_unit()
	)
	var developer_api_pressure_rate: int = (
		market_state.get_developer_api_opponent_pressure_bps_per_served_unit()
	)
	if (
		not _can_multiply_non_negative(opponent_consumer_served, consumer_pressure_rate)
		or not _can_multiply_non_negative(
			opponent_developer_api_served,
			developer_api_pressure_rate
		)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var consumer_pressure: int = opponent_consumer_served * consumer_pressure_rate
	var developer_api_pressure: int = (
		opponent_developer_api_served * developer_api_pressure_rate
	)
	if (
		not _can_add(consumer_share_after_organic, -consumer_pressure)
		or not _can_add(developer_api_share_after_organic, -developer_api_pressure)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var consumer_share_after: int = clampi(
		consumer_share_after_organic - consumer_pressure,
		0,
		TOTAL_BASIS_POINTS
	)
	var developer_api_share_after: int = clampi(
		developer_api_share_after_organic - developer_api_pressure,
		0,
		TOTAL_BASIS_POINTS
	)
	if (
		not _can_subtract(consumer_share_after, consumer_share_after_organic)
		or not _can_subtract(
			developer_api_share_after,
			developer_api_share_after_organic
		)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var consumer_opponent_pressure_delta: int = (
		consumer_share_after - consumer_share_after_organic
	)
	var developer_api_opponent_pressure_delta: int = (
		developer_api_share_after - developer_api_share_after_organic
	)

	var consumer_revenue_after: int = _calculate_market_revenue(
		market_state.get_consumer_addressable_monthly_revenue_cents(),
		consumer_share_after,
		consumer_served,
		consumer_workload
	)
	var developer_api_revenue_after: int = _calculate_market_revenue(
		market_state.get_developer_api_addressable_monthly_revenue_cents(),
		developer_api_share_after,
		developer_api_served,
		developer_api_workload
	)
	if consumer_revenue_after < 0 or developer_api_revenue_after < 0:
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)

	var consumer_revenue_before: int = (
		market_state.get_consumer_current_market_revenue_cents()
	)
	var developer_api_revenue_before: int = (
		market_state.get_developer_api_current_market_revenue_cents()
	)
	if (
		not _can_subtract(consumer_revenue_after, consumer_revenue_before)
		or not _can_subtract(developer_api_revenue_after, developer_api_revenue_before)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var consumer_revenue_delta: int = consumer_revenue_after - consumer_revenue_before
	var developer_api_revenue_delta: int = (
		developer_api_revenue_after - developer_api_revenue_before
	)

	var consumer_cumulative_served_before: int = (
		market_state.get_consumer_cumulative_served_compute_unit_months()
	)
	var consumer_cumulative_unmet_before: int = (
		market_state.get_consumer_cumulative_unmet_compute_unit_months()
	)
	var developer_api_cumulative_served_before: int = (
		market_state.get_developer_api_cumulative_served_compute_unit_months()
	)
	var developer_api_cumulative_unmet_before: int = (
		market_state.get_developer_api_cumulative_unmet_compute_unit_months()
	)
	if (
		not _can_add_non_negative(consumer_cumulative_served_before, consumer_served)
		or not _can_add_non_negative(consumer_cumulative_unmet_before, consumer_unmet)
		or not _can_add_non_negative(
			developer_api_cumulative_served_before,
			developer_api_served
		)
		or not _can_add_non_negative(
			developer_api_cumulative_unmet_before,
			developer_api_unmet
		)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var consumer_cumulative_served_after: int = (
		consumer_cumulative_served_before + consumer_served
	)
	var consumer_cumulative_unmet_after: int = (
		consumer_cumulative_unmet_before + consumer_unmet
	)
	var developer_api_cumulative_served_after: int = (
		developer_api_cumulative_served_before + developer_api_served
	)
	var developer_api_cumulative_unmet_after: int = (
		developer_api_cumulative_unmet_before + developer_api_unmet
	)

	if not _can_add_non_negative(consumer_revenue_before, developer_api_revenue_before):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	if not _can_add_non_negative(consumer_revenue_after, developer_api_revenue_after):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var old_market_revenue: int = consumer_revenue_before + developer_api_revenue_before
	var new_market_revenue: int = consumer_revenue_after + developer_api_revenue_after
	var company_revenue_before: int = company_state.get_monthly_revenue_cents()
	if not _can_subtract(company_revenue_before, old_market_revenue):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var non_market_revenue: int = company_revenue_before - old_market_revenue
	if not _can_add_non_negative(non_market_revenue, new_market_revenue):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var company_revenue_after: int = non_market_revenue + new_market_revenue

	if (
		not _can_add(consumer_revenue_delta, developer_api_revenue_delta)
		or not _can_subtract(new_market_revenue, old_market_revenue)
		or not _can_subtract(company_revenue_after, company_revenue_before)
	):
		return _failed(EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW)
	var emitted_revenue_delta: int = consumer_revenue_delta + developer_api_revenue_delta
	if (
		emitted_revenue_delta != new_market_revenue - old_market_revenue
		or emitted_revenue_delta != company_revenue_after - company_revenue_before
	):
		return _failed(EffectBatchResultType.ErrorCode.INVALID_STATE)

	var contributions: Array[EffectContributionType] = []
	_append_market_contributions(
		contributions,
		EffectContributionType.SUBJECT_CONSUMER,
		consumer_served,
		consumer_unmet,
		consumer_organic_share_delta,
		consumer_opponent_pressure_delta,
		consumer_revenue_delta
	)
	_append_market_contributions(
		contributions,
		EffectContributionType.SUBJECT_DEVELOPER_API,
		developer_api_served,
		developer_api_unmet,
		developer_api_organic_share_delta,
		developer_api_opponent_pressure_delta,
		developer_api_revenue_delta
	)

	market_state._commit_month(
		consumer_share_after,
		developer_api_share_after,
		consumer_served,
		developer_api_served,
		consumer_revenue_after,
		developer_api_revenue_after,
		consumer_cumulative_served_after,
		consumer_cumulative_unmet_after,
		developer_api_cumulative_served_after,
		developer_api_cumulative_unmet_after
	)
	company_state._commit_financials(
		company_state.get_cash_cents(),
		company_revenue_after
	)
	return EffectBatchResultType.new(EffectBatchResultType.ErrorCode.NONE, contributions)


func _validate_market_state(
	company_state: CompanyStateType,
	compute_state: ComputeStateType,
	market_state: MarketStateType
) -> EffectBatchResultType.ErrorCode:
	if market_state == null:
		return EffectBatchResultType.ErrorCode.INVALID_STATE
	if (
		market_state.get_consumer_workload_units_per_month() < 0
		or market_state.get_developer_api_workload_units_per_month() < 0
		or market_state.get_consumer_addressable_monthly_revenue_cents() < 0
		or market_state.get_developer_api_addressable_monthly_revenue_cents() < 0
		or market_state.get_consumer_full_service_growth_bps() < 0
		or market_state.get_developer_api_full_service_growth_bps() < 0
		or market_state.get_consumer_unmet_penalty_bps_per_unit() < 0
		or market_state.get_developer_api_unmet_penalty_bps_per_unit() < 0
		or market_state.get_consumer_current_served_units_per_month() < 0
		or market_state.get_developer_api_current_served_units_per_month() < 0
		or market_state.get_consumer_current_market_revenue_cents() < 0
		or market_state.get_developer_api_current_market_revenue_cents() < 0
		or market_state.get_consumer_cumulative_served_compute_unit_months() < 0
		or market_state.get_consumer_cumulative_unmet_compute_unit_months() < 0
		or market_state.get_developer_api_cumulative_served_compute_unit_months() < 0
		or market_state.get_developer_api_cumulative_unmet_compute_unit_months() < 0
		or market_state.get_consumer_opponent_pressure_bps_per_served_unit() < 0
		or market_state.get_developer_api_opponent_pressure_bps_per_served_unit() < 0
	):
		return EffectBatchResultType.ErrorCode.INVALID_STATE
	if (
		market_state.get_consumer_service_allocation_bps() < 0
		or market_state.get_consumer_service_allocation_bps() > TOTAL_BASIS_POINTS
		or market_state.get_consumer_player_share_bps() < 0
		or market_state.get_consumer_player_share_bps() > TOTAL_BASIS_POINTS
		or market_state.get_developer_api_player_share_bps() < 0
		or market_state.get_developer_api_player_share_bps() > TOTAL_BASIS_POINTS
	):
		return EffectBatchResultType.ErrorCode.INVALID_STATE
	if (
		market_state.get_consumer_current_served_units_per_month()
		> market_state.get_consumer_workload_units_per_month()
		or market_state.get_developer_api_current_served_units_per_month()
		> market_state.get_developer_api_workload_units_per_month()
	):
		return EffectBatchResultType.ErrorCode.INVALID_STATE

	var consumer_workload: int = market_state.get_consumer_workload_units_per_month()
	var developer_api_workload: int = (
		market_state.get_developer_api_workload_units_per_month()
	)
	if not _can_add_non_negative(consumer_workload, developer_api_workload):
		return EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	var total_workload: int = consumer_workload + developer_api_workload
	if total_workload > MAX_WORKLOAD_FOR_BASIS_POINT_CONVERSION:
		return EffectBatchResultType.ErrorCode.INVALID_STATE
	if total_workload != compute_state.get_inference_workload_units_per_month():
		return EffectBatchResultType.ErrorCode.INVALID_STATE
	var expected_consumer_workload: int = _floor_by_basis_points(
		total_workload,
		market_state.get_consumer_service_allocation_bps()
	)
	if expected_consumer_workload < 0:
		return EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	if (
		expected_consumer_workload != consumer_workload
		or total_workload - expected_consumer_workload != developer_api_workload
	):
		return EffectBatchResultType.ErrorCode.INVALID_STATE

	var consumer_current_served: int = (
		market_state.get_consumer_current_served_units_per_month()
	)
	var developer_api_current_served: int = (
		market_state.get_developer_api_current_served_units_per_month()
	)
	if not _can_add_non_negative(consumer_current_served, developer_api_current_served):
		return EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	var total_current_served: int = consumer_current_served + developer_api_current_served
	var expected_consumer_current_served: int = _floor_by_basis_points(
		total_current_served,
		market_state.get_consumer_service_allocation_bps()
	)
	if expected_consumer_current_served < 0:
		return EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	if (
		expected_consumer_current_served != consumer_current_served
		or total_current_served - expected_consumer_current_served
			!= developer_api_current_served
	):
		return EffectBatchResultType.ErrorCode.INVALID_STATE

	var expected_consumer_revenue: int = _calculate_market_revenue(
		market_state.get_consumer_addressable_monthly_revenue_cents(),
		market_state.get_consumer_player_share_bps(),
		market_state.get_consumer_current_served_units_per_month(),
		consumer_workload
	)
	var expected_developer_api_revenue: int = _calculate_market_revenue(
		market_state.get_developer_api_addressable_monthly_revenue_cents(),
		market_state.get_developer_api_player_share_bps(),
		market_state.get_developer_api_current_served_units_per_month(),
		developer_api_workload
	)
	if expected_consumer_revenue < 0 or expected_developer_api_revenue < 0:
		return EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	if (
		expected_consumer_revenue
		!= market_state.get_consumer_current_market_revenue_cents()
		or expected_developer_api_revenue
		!= market_state.get_developer_api_current_market_revenue_cents()
	):
		return EffectBatchResultType.ErrorCode.INVALID_STATE
	if not _can_add_non_negative(
		market_state.get_consumer_current_market_revenue_cents(),
		market_state.get_developer_api_current_market_revenue_cents()
	):
		return EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	var old_market_revenue: int = (
		market_state.get_consumer_current_market_revenue_cents()
		+ market_state.get_developer_api_current_market_revenue_cents()
	)
	if old_market_revenue > company_state.get_monthly_revenue_cents():
		return EffectBatchResultType.ErrorCode.INVALID_STATE
	return EffectBatchResultType.ErrorCode.NONE


func _is_company_state_valid(company_state: CompanyStateType) -> bool:
	return (
		company_state != null
		and company_state.get_monthly_revenue_cents() >= 0
		and company_state.get_monthly_operating_cost_cents() >= 0
	)


func _is_compute_state_valid(compute_state: ComputeStateType) -> bool:
	if compute_state == null:
		return false
	if (
		compute_state.get_total_units_per_month() < 0
		or compute_state.get_reserve_units_per_month() < 0
		or compute_state.get_inference_workload_units_per_month() < 0
		or compute_state.get_training_allocation_units_per_month() < 0
		or compute_state.get_cumulative_training_compute_unit_months() < 0
		or compute_state.get_cumulative_served_inference_compute_unit_months() < 0
		or compute_state.get_cumulative_unmet_inference_compute_unit_months() < 0
	):
		return false
	if compute_state.get_reserve_units_per_month() > compute_state.get_total_units_per_month():
		return false
	return (
		compute_state.get_training_allocation_units_per_month()
		<= compute_state.get_allocatable_capacity_units_per_month()
	)


## The exact all-zero default is the backward-compatible no-market fixture.
func _is_zero_market_state(market_state: MarketStateType) -> bool:
	return (
		market_state.get_consumer_workload_units_per_month() == 0
		and market_state.get_developer_api_workload_units_per_month() == 0
		and market_state.get_consumer_service_allocation_bps() == 0
		and market_state.get_consumer_player_share_bps() == 0
		and market_state.get_developer_api_player_share_bps() == 0
		and market_state.get_consumer_addressable_monthly_revenue_cents() == 0
		and market_state.get_developer_api_addressable_monthly_revenue_cents() == 0
		and market_state.get_consumer_full_service_growth_bps() == 0
		and market_state.get_developer_api_full_service_growth_bps() == 0
		and market_state.get_consumer_unmet_penalty_bps_per_unit() == 0
		and market_state.get_developer_api_unmet_penalty_bps_per_unit() == 0
		and market_state.get_consumer_current_served_units_per_month() == 0
		and market_state.get_developer_api_current_served_units_per_month() == 0
		and market_state.get_consumer_current_market_revenue_cents() == 0
		and market_state.get_developer_api_current_market_revenue_cents() == 0
		and market_state.get_consumer_cumulative_served_compute_unit_months() == 0
		and market_state.get_consumer_cumulative_unmet_compute_unit_months() == 0
		and market_state.get_developer_api_cumulative_served_compute_unit_months() == 0
		and market_state.get_developer_api_cumulative_unmet_compute_unit_months() == 0
		and market_state.get_consumer_opponent_pressure_bps_per_served_unit() == 0
		and market_state.get_developer_api_opponent_pressure_bps_per_served_unit() == 0
	)


func _append_market_contributions(
	contributions: Array[EffectContributionType],
	subject_key: StringName,
	served: int,
	unmet: int,
	organic_share_delta: int,
	opponent_pressure_delta: int,
	revenue_delta: int
) -> void:
	if served != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_MARKET,
			EffectContributionType.REASON_MARKET_SERVED,
			subject_key,
			EffectContributionType.METRIC_CUMULATIVE_MARKET_SERVED_COMPUTE_UNIT_MONTHS,
			EffectContributionType.Unit.COMPUTE_UNIT_MONTHS,
			served
		))
	if unmet != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_MARKET,
			EffectContributionType.REASON_MARKET_UNMET,
			subject_key,
			EffectContributionType.METRIC_CUMULATIVE_MARKET_UNMET_COMPUTE_UNIT_MONTHS,
			EffectContributionType.Unit.COMPUTE_UNIT_MONTHS,
			unmet
		))
	if organic_share_delta != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_MARKET,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE,
			subject_key,
			EffectContributionType.METRIC_PLAYER_SHARE_BPS,
			EffectContributionType.Unit.BASIS_POINTS,
			organic_share_delta
		))
	if opponent_pressure_delta != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_MARKET,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
			subject_key,
			EffectContributionType.METRIC_PLAYER_SHARE_BPS,
			EffectContributionType.Unit.BASIS_POINTS,
			opponent_pressure_delta
		))
	if revenue_delta != 0:
		contributions.append(EffectContributionType.new(
			EffectContributionType.SOURCE_MARKET,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			subject_key,
			EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS,
			EffectContributionType.Unit.CENTS,
			revenue_delta
		))


## Returns floor(value * bps / 10000) without constructing the wide product.
@warning_ignore("integer_division")
func _floor_by_basis_points(value: int, bps: int) -> int:
	if value < 0 or bps < 0 or bps > TOTAL_BASIS_POINTS:
		return -1
	var whole: int = value / TOTAL_BASIS_POINTS
	var remainder: int = value % TOTAL_BASIS_POINTS
	if (
		not _can_multiply_non_negative(whole, bps)
		or not _can_multiply_non_negative(remainder, bps)
	):
		return -1
	var whole_result: int = whole * bps
	var remainder_product: int = remainder * bps
	var remainder_result: int = remainder_product / TOTAL_BASIS_POINTS
	if not _can_add_non_negative(whole_result, remainder_result):
		return -1
	return whole_result + remainder_result


@warning_ignore("integer_division")
func _get_fulfillment_bps(served: int, workload: int) -> int:
	if served < 0 or workload < 0 or served > workload:
		return -1
	if workload == 0:
		return 0
	if not _can_multiply_non_negative(served, TOTAL_BASIS_POINTS):
		return -1
	return (served * TOTAL_BASIS_POINTS) / workload


func _calculate_market_revenue(
	addressable_revenue_cents: int,
	player_share_bps: int,
	served: int,
	workload: int
) -> int:
	var share_revenue_cents: int = _floor_by_basis_points(
		addressable_revenue_cents,
		player_share_bps
	)
	var fulfillment_bps: int = _get_fulfillment_bps(served, workload)
	if share_revenue_cents < 0 or fulfillment_bps < 0:
		return -1
	return _floor_by_basis_points(share_revenue_cents, fulfillment_bps)


func _failed(error_code: EffectBatchResultType.ErrorCode) -> EffectBatchResultType:
	var no_contributions: Array[EffectContributionType] = []
	return EffectBatchResultType.new(error_code, no_contributions)


func _can_add(value: int, delta: int) -> bool:
	if delta > 0:
		return value <= MAX_SIGNED_INT - delta
	if delta < 0:
		return value >= MIN_SIGNED_INT - delta
	return true


func _can_subtract(value: int, subtrahend: int) -> bool:
	if subtrahend > 0:
		return value >= MIN_SIGNED_INT + subtrahend
	if subtrahend < 0:
		return value <= MAX_SIGNED_INT + subtrahend
	return true


func _can_add_non_negative(value: int, delta: int) -> bool:
	return value >= 0 and delta >= 0 and value <= MAX_SIGNED_INT - delta


@warning_ignore("integer_division")
func _can_multiply_non_negative(value: int, multiplier: int) -> bool:
	if value < 0 or multiplier < 0:
		return false
	if value == 0 or multiplier == 0:
		return true
	return value <= MAX_SIGNED_INT / multiplier
