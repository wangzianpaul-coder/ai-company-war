extends RefCounted


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const ComputeSystemType = preload("res://simulation/systems/compute_system.gd")
const MarketSystemType = preload("res://simulation/systems/market_system.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807


static func run(report: Callable) -> void:
	var all_passed: bool = true
	all_passed = _test_copy_isolation_and_zero_compatibility() and all_passed
	all_passed = _test_bps_workload_rounding_and_effect_order() and all_passed
	all_passed = _test_post_clamp_deltas() and all_passed
	all_passed = _test_two_stage_revenue_floor() and all_passed
	all_passed = _test_default_and_training_70_golden_cases() and all_passed
	all_passed = _test_invalid_mismatch_and_overflow_atomicity() and all_passed
	all_passed = _test_deterministic_100_case_sweep() and all_passed
	_report(
		report,
		all_passed,
		"TP-021 two-market settlement preserves 10000-bps invariants"
	)


static func _test_copy_isolation_and_zero_compatibility() -> bool:
	var source_market: MarketStateType = _create_demo_market(7, 8, 9, 10)
	var source_state: GameStateType = GameStateType.new(
		CompanyStateType.new(0, 120_000, 0),
		null,
		ComputeStateType.new(100, 10, 50, 40),
		source_market
	)
	var initial_fields: Array = [
		30, 20, 6_000, 3_000, 2_000, 100_000, 450_000, 30, 10, 10, 25,
		30, 20, 30_000, 90_000, 7, 8, 9, 10,
	]
	if source_state.get_market() == source_market:
		return false
	var market_system: MarketSystemType = MarketSystemType.new()
	var input_market_result: EffectBatchResultType = market_system.settle_month(
		CompanyStateType.new(0, 120_000, 0),
		ComputeStateType.new(100, 10, 50, 40),
		source_market
	)
	if (
		not input_market_result.is_successful()
		or not _market_fields_match(source_state.get_market(), initial_fields)
	):
		return false
	var input_market_after: MarketStateType = source_market.copy()
	var copied_state: GameStateType = source_state.copy()
	if (
		copied_state == null
		or copied_state.get_market() == source_state.get_market()
		or not _market_fields_match(copied_state.get_market(), initial_fields)
	):
		return false

	var copied_result: EffectBatchResultType = market_system.settle_month(
		copied_state.get_company(),
		copied_state.get_compute(),
		copied_state.get_market()
	)
	if (
		not copied_result.is_successful()
		or not _market_fields_match(source_state.get_market(), initial_fields)
		or not _market_fields_match(copied_state.get_market(), [
			30, 20, 6_000, 3_030, 2_010, 100_000, 450_000, 30, 10, 10, 25,
			30, 20, 30_300, 90_450, 37, 8, 29, 10,
		])
		or copied_state.get_company().get_monthly_revenue_cents() != 120_750
	):
		return false

	var copied_market_after: MarketStateType = copied_state.get_market().copy()
	var allocation_result: EffectBatchResultType = (
		ComputeSystemType.new().set_training_allocation(source_state.get_compute(), 70)
	)
	var source_result: EffectBatchResultType = market_system.settle_month(
		source_state.get_company(),
		source_state.get_compute(),
		source_state.get_market()
	)
	if (
		not allocation_result.is_successful()
		or not source_result.is_successful()
		or not _market_states_equal(copied_state.get_market(), copied_market_after)
		or not _market_states_equal(source_market, input_market_after)
		or not _market_fields_match(source_state.get_market(), [
			30, 20, 6_000, 2_820, 1_700, 100_000, 450_000, 30, 10, 10, 25,
			12, 8, 11_280, 30_600, 19, 26, 17, 22,
		])
		or source_state.get_company().get_monthly_revenue_cents() != 41_880
	):
		return false

	var zero_state: GameStateType = GameStateType.new()
	var zero_before: GameStateType = zero_state.copy()
	var zero_result: EffectBatchResultType = market_system.settle_month(
		zero_state.get_company(),
		zero_state.get_compute(),
		zero_state.get_market()
	)
	return (
		zero_result.is_successful()
		and zero_result.get_contributions().is_empty()
		and _game_states_equal(zero_state, zero_before)
		and zero_state.get_market().get_consumer_service_allocation_bps() == 0
		and zero_state.get_market().get_developer_api_service_allocation_bps() == 10_000
		and zero_state.get_market().get_consumer_outside_share_bps() == 10_000
		and zero_state.get_market().get_developer_api_outside_share_bps() == 10_000
	)


static func _test_post_clamp_deltas() -> bool:
	var system: MarketSystemType = MarketSystemType.new()
	var upper_market: MarketStateType = MarketStateType.new(
		1, 0, 10_000, 9_995, 0, 100_000, 0, 30, 0, 0, 0,
		1, 0, 99_950, 0
	)
	var upper_company: CompanyStateType = CompanyStateType.new(0, 99_950, 0)
	var upper_result: EffectBatchResultType = system.settle_month(
		upper_company,
		ComputeStateType.new(1, 0, 1, 0),
		upper_market
	)
	if (
		not upper_result.is_successful()
		or upper_market.get_consumer_player_share_bps() != 10_000
		or upper_market.get_consumer_outside_share_bps() != 0
		or upper_market.get_consumer_current_market_revenue_cents() != 100_000
		or upper_company.get_monthly_revenue_cents() != 100_000
		or _sum_market_delta(
			upper_result.get_contributions(),
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE
		) != 5
		or _sum_market_delta(
			upper_result.get_contributions(),
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		) != 50
	):
		return false

	var lower_market: MarketStateType = MarketStateType.new(
		1, 0, 10_000, 5, 0, 100_000, 0, 0, 0, 10, 0,
		1, 0, 50, 0
	)
	var lower_company: CompanyStateType = CompanyStateType.new(0, 50, 0)
	var lower_result: EffectBatchResultType = system.settle_month(
		lower_company,
		ComputeStateType.new(0, 0, 1, 0),
		lower_market
	)
	return (
		lower_result.is_successful()
		and lower_market.get_consumer_player_share_bps() == 0
		and lower_market.get_consumer_outside_share_bps() == 10_000
		and lower_market.get_consumer_current_market_revenue_cents() == 0
		and lower_company.get_monthly_revenue_cents() == 0
		and _sum_market_delta(
			lower_result.get_contributions(),
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE
		) == -5
		and _sum_market_delta(
			lower_result.get_contributions(),
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		) == -50
	)


static func _test_two_stage_revenue_floor() -> bool:
	var market: MarketStateType = MarketStateType.new(
		5, 0, 10_000, 6_250, 0, 2, 0, 0, 0, 0, 0,
		5, 0, 1, 0
	)
	var company: CompanyStateType = CompanyStateType.new(0, 1, 0)
	var result: EffectBatchResultType = MarketSystemType.new().settle_month(
		company,
		ComputeStateType.new(4, 0, 5, 0),
		market
	)
	return (
		result.is_successful()
		and market.get_consumer_current_served_units_per_month() == 4
		and market.get_consumer_current_market_revenue_cents() == 0
		and company.get_monthly_revenue_cents() == 0
		and _sum_market_delta(
			result.get_contributions(),
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		) == -1
	)


static func _test_bps_workload_rounding_and_effect_order() -> bool:
	var market: MarketStateType = MarketStateType.new(
		1,
		2,
		3_334,
		3_333,
		2_222,
		10_001,
		10_003,
		7,
		1,
		1,
		2,
		1,
		2,
		3_333,
		2_222
	)
	var company: CompanyStateType = CompanyStateType.new(0, 5_555, 0)
	var compute: ComputeStateType = ComputeStateType.new(2, 0, 3, 0)
	var result: EffectBatchResultType = MarketSystemType.new().settle_month(
		company,
		compute,
		market
	)
	if not result.is_successful():
		return false
	var trace: Array[EffectContributionType] = result.get_contributions()
	var order_exact: bool = trace.size() == 6
	if order_exact:
		order_exact = (
			_market_effect_matches(
				trace[0],
				EffectContributionType.SUBJECT_CONSUMER,
				EffectContributionType.REASON_MARKET_UNMET,
				1
			)
			and _market_effect_matches(
				trace[1],
				EffectContributionType.SUBJECT_CONSUMER,
				EffectContributionType.REASON_MARKET_SHARE_CHANGE,
				-1
			)
			and _market_effect_matches(
				trace[2],
				EffectContributionType.SUBJECT_CONSUMER,
				EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
				-3_333
			)
			and _market_effect_matches(
				trace[3],
				EffectContributionType.SUBJECT_DEVELOPER_API,
				EffectContributionType.REASON_MARKET_SERVED,
				2
			)
			and _market_effect_matches(
				trace[4],
				EffectContributionType.SUBJECT_DEVELOPER_API,
				EffectContributionType.REASON_MARKET_SHARE_CHANGE,
				1
			)
			and _market_effect_matches(
				trace[5],
				EffectContributionType.SUBJECT_DEVELOPER_API,
				EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
				1
			)
		)
	return (
		market.get_consumer_service_allocation_bps()
			+ market.get_developer_api_service_allocation_bps() == 10_000
		and market.get_consumer_player_share_bps()
			+ market.get_consumer_outside_share_bps() == 10_000
		and market.get_developer_api_player_share_bps()
			+ market.get_developer_api_outside_share_bps() == 10_000
		and market.get_consumer_current_served_units_per_month() == 0
		and market.get_developer_api_current_served_units_per_month() == 2
		and market.get_consumer_cumulative_unmet_compute_unit_months() == 1
		and market.get_developer_api_cumulative_served_compute_unit_months() == 2
		and market.get_consumer_player_share_bps() == 3_332
		and market.get_developer_api_player_share_bps() == 2_223
		and market.get_consumer_current_market_revenue_cents() == 0
		and market.get_developer_api_current_market_revenue_cents() == 2_223
		and company.get_monthly_revenue_cents() == 2_223
		and compute.get_served_inference_units_per_month() == 2
		and compute.get_unmet_inference_units_per_month() == 1
		and EffectContributionType.Unit.CENTS == 0
		and EffectContributionType.Unit.MONTHS == 1
		and EffectContributionType.Unit.COMPUTE_UNIT_MONTHS == 2
		and EffectContributionType.Unit.BASIS_POINTS == 3
		and order_exact
	)


static func _test_default_and_training_70_golden_cases() -> bool:
	var system: MarketSystemType = MarketSystemType.new()
	var default_company: CompanyStateType = CompanyStateType.new(0, 120_000, 0)
	var default_compute: ComputeStateType = ComputeStateType.new(100, 10, 50, 40)
	var default_market: MarketStateType = _create_demo_market()
	var default_trace: Array[EffectContributionType] = []
	var default_success: bool = true
	for _month_index in 3:
		var result: EffectBatchResultType = system.settle_month(
			default_company,
			default_compute,
			default_market
		)
		default_success = result.is_successful() and default_success
		_append(default_trace, result.get_contributions())
	var default_exact: bool = (
		default_success
		and default_trace.size() == 18
		and default_market.get_consumer_current_served_units_per_month() == 30
		and default_market.get_developer_api_current_served_units_per_month() == 20
		and default_market.get_consumer_cumulative_served_compute_unit_months() == 90
		and default_market.get_consumer_cumulative_unmet_compute_unit_months() == 0
		and default_market.get_developer_api_cumulative_served_compute_unit_months() == 60
		and default_market.get_developer_api_cumulative_unmet_compute_unit_months() == 0
		and default_market.get_consumer_player_share_bps() == 3_090
		and default_market.get_developer_api_player_share_bps() == 2_030
		and default_market.get_consumer_current_market_revenue_cents() == 30_900
		and default_market.get_developer_api_current_market_revenue_cents() == 91_350
		and default_company.get_monthly_revenue_cents() == 122_250
		and _sum_market_delta(
			default_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SERVED
		) == 90
		and _sum_market_delta(
			default_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_UNMET
		) == 0
		and _sum_market_delta(
			default_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE
		) == 90
		and _sum_market_delta(
			default_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		) == 900
		and _sum_market_delta(
			default_trace,
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_SERVED
		) == 60
		and _sum_market_delta(
			default_trace,
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE
		) == 30
		and _sum_market_delta(
			default_trace,
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		) == 1_350
	)

	var constrained_company: CompanyStateType = CompanyStateType.new(0, 120_000, 0)
	var constrained_compute: ComputeStateType = ComputeStateType.new(100, 10, 50, 70)
	var constrained_market: MarketStateType = _create_demo_market()
	var constrained_trace: Array[EffectContributionType] = []
	var constrained_success: bool = true
	for _month_index in 3:
		var result: EffectBatchResultType = system.settle_month(
			constrained_company,
			constrained_compute,
			constrained_market
		)
		constrained_success = result.is_successful() and constrained_success
		_append(constrained_trace, result.get_contributions())
	var constrained_exact: bool = (
		constrained_success
		and constrained_trace.size() == 24
		and constrained_market.get_consumer_current_served_units_per_month() == 12
		and constrained_market.get_developer_api_current_served_units_per_month() == 8
		and constrained_market.get_consumer_cumulative_served_compute_unit_months() == 36
		and constrained_market.get_consumer_cumulative_unmet_compute_unit_months() == 54
		and constrained_market.get_developer_api_cumulative_served_compute_unit_months() == 24
		and constrained_market.get_developer_api_cumulative_unmet_compute_unit_months() == 36
		and constrained_market.get_consumer_player_share_bps() == 2_460
		and constrained_market.get_developer_api_player_share_bps() == 1_100
		and constrained_market.get_consumer_current_market_revenue_cents() == 9_840
		and constrained_market.get_developer_api_current_market_revenue_cents() == 19_800
		and constrained_company.get_monthly_revenue_cents() == 29_640
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SERVED
		) == 36
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_UNMET
		) == 54
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE
		) == -540
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_CONSUMER,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		) == -20_160
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_SERVED
		) == 24
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_UNMET
		) == 36
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_SHARE_CHANGE
		) == -900
		and _sum_market_delta(
			constrained_trace,
			EffectContributionType.SUBJECT_DEVELOPER_API,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE
		) == -70_200
	)
	return default_exact and constrained_exact


static func _test_invalid_mismatch_and_overflow_atomicity() -> bool:
	var system: MarketSystemType = MarketSystemType.new()
	var all_atomic: bool = true
	var null_company: CompanyStateType = null
	var null_compute: ComputeStateType = null
	var null_market: MarketStateType = null
	all_atomic = _failed_atomic(
		system,
		null_company,
		ComputeStateType.new(100, 10, 50, 40),
		_create_demo_market(),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 120_000, 0),
		null_compute,
		_create_demo_market(),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 120_000, 0),
		ComputeStateType.new(100, 10, 50, 40),
		null_market,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic

	var invalid_share: MarketStateType = MarketStateType.new(
		30, 20, 6_000, 10_001, 2_000, 100_000, 450_000, 30, 10, 10, 25,
		30, 20, 100_000, 90_000
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 190_000, 0),
		ComputeStateType.new(100, 10, 50, 40),
		invalid_share,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic

	var split_mismatch: MarketStateType = MarketStateType.new(
		29, 21, 6_000, 3_000, 2_000, 100_000, 450_000, 30, 10, 10, 25,
		29, 21, 30_000, 90_000
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 120_000, 0),
		ComputeStateType.new(100, 10, 50, 40),
		split_mismatch,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 120_000, 0),
		ComputeStateType.new(100, 10, 49, 40),
		_create_demo_market(),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic

	var stored_served_split_mismatch: MarketStateType = MarketStateType.new(
		30, 20, 6_000, 3_000, 2_000, 100_000, 450_000, 30, 10, 10, 25,
		20, 0, 19_998, 0
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 19_998, 0),
		ComputeStateType.new(100, 10, 50, 40),
		stored_served_split_mismatch,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic

	var stored_revenue_mismatch: MarketStateType = MarketStateType.new(
		30, 20, 6_000, 3_000, 2_000, 100_000, 450_000, 30, 10, 10, 25,
		30, 20, 29_999, 90_000
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 120_000, 0),
		ComputeStateType.new(100, 10, 50, 40),
		stored_revenue_mismatch,
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, 119_999, 0),
		ComputeStateType.new(100, 10, 50, 40),
		_create_demo_market(),
		EffectBatchResultType.ErrorCode.INVALID_STATE
	) and all_atomic

	var multiply_overflow: MarketStateType = MarketStateType.new(
		2, 0, 10_000, 0, 0, 0, 0, 0, 0, MAX_SIGNED_INT, 0
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(),
		ComputeStateType.new(0, 0, 2, 0),
		multiply_overflow,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	) and all_atomic

	var share_add_overflow: MarketStateType = MarketStateType.new(
		1, 0, 10_000, 1, 0, 0, 0, MAX_SIGNED_INT, 0, 0, 0, 1
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(),
		ComputeStateType.new(1, 0, 1, 0),
		share_add_overflow,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	) and all_atomic

	var cumulative_add_overflow: MarketStateType = MarketStateType.new(
		1, 0, 10_000, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
		MAX_SIGNED_INT
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(),
		ComputeStateType.new(1, 0, 1, 0),
		cumulative_add_overflow,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	) and all_atomic

	var old_market_sum_overflow: MarketStateType = MarketStateType.new(
		1, 1, 5_000, 10_000, 10_000, MAX_SIGNED_INT, MAX_SIGNED_INT,
		0, 0, 0, 0, 1, 1, MAX_SIGNED_INT, MAX_SIGNED_INT
	)
	all_atomic = _failed_atomic(
		system,
		CompanyStateType.new(0, MAX_SIGNED_INT, 0),
		ComputeStateType.new(2, 0, 2, 0),
		old_market_sum_overflow,
		EffectBatchResultType.ErrorCode.ARITHMETIC_OVERFLOW
	) and all_atomic
	return all_atomic


static func _test_deterministic_100_case_sweep() -> bool:
	var system: MarketSystemType = MarketSystemType.new()
	for case_index in 100:
		var allocation: int = case_index % 91
		var first_company: CompanyStateType = CompanyStateType.new(0, 120_000, 0)
		var second_company: CompanyStateType = CompanyStateType.new(0, 120_000, 0)
		var first_compute: ComputeStateType = ComputeStateType.new(100, 10, 50, allocation)
		var second_compute: ComputeStateType = first_compute.copy()
		var first_market: MarketStateType = _create_demo_market()
		var second_market: MarketStateType = _create_demo_market()
		var first_result: EffectBatchResultType = system.settle_month(
			first_company,
			first_compute,
			first_market
		)
		var second_result: EffectBatchResultType = system.settle_month(
			second_company,
			second_compute,
			second_market
		)
		if (
			not first_result.is_successful()
			or not second_result.is_successful()
			or not _market_states_equal(first_market, second_market)
			or first_company.get_monthly_revenue_cents()
				!= second_company.get_monthly_revenue_cents()
			or not _traces_equal(
				first_result.get_contributions(),
				second_result.get_contributions()
			)
			or first_market.get_consumer_current_served_units_per_month()
				+ first_market.get_developer_api_current_served_units_per_month()
				!= first_compute.get_served_inference_units_per_month()
			or first_market.get_consumer_current_served_units_per_month()
				!= first_market.get_consumer_cumulative_served_compute_unit_months()
			or first_market.get_developer_api_current_served_units_per_month()
				!= first_market.get_developer_api_cumulative_served_compute_unit_months()
			or first_market.get_consumer_current_served_units_per_month()
				+ first_market.get_consumer_cumulative_unmet_compute_unit_months()
				!= first_market.get_consumer_workload_units_per_month()
			or first_market.get_developer_api_current_served_units_per_month()
				+ first_market.get_developer_api_cumulative_unmet_compute_unit_months()
				!= first_market.get_developer_api_workload_units_per_month()
			or first_market.get_consumer_player_share_bps() < 0
			or first_market.get_consumer_player_share_bps() > 10_000
			or first_market.get_developer_api_player_share_bps() < 0
			or first_market.get_developer_api_player_share_bps() > 10_000
			or first_market.get_consumer_player_share_bps()
				+ first_market.get_consumer_outside_share_bps() != 10_000
			or first_market.get_developer_api_player_share_bps()
				+ first_market.get_developer_api_outside_share_bps() != 10_000
		):
			return false
	return true


static func _create_demo_market(
	consumer_cumulative_served: int = 0,
	consumer_cumulative_unmet: int = 0,
	developer_cumulative_served: int = 0,
	developer_cumulative_unmet: int = 0
) -> MarketStateType:
	return MarketStateType.new(
		30,
		20,
		6_000,
		3_000,
		2_000,
		100_000,
		450_000,
		30,
		10,
		10,
		25,
		30,
		20,
		30_000,
		90_000,
		consumer_cumulative_served,
		consumer_cumulative_unmet,
		developer_cumulative_served,
		developer_cumulative_unmet
	)


static func _failed_atomic(
	system: MarketSystemType,
	company: CompanyStateType,
	compute: ComputeStateType,
	market: MarketStateType,
	expected_error_code: int
) -> bool:
	var cash_before: int = company.get_cash_cents() if company != null else 0
	var revenue_before: int = company.get_monthly_revenue_cents() if company != null else 0
	var cost_before: int = (
		company.get_monthly_operating_cost_cents() if company != null else 0
	)
	var compute_before: ComputeStateType = compute.copy() if compute != null else null
	var market_before: MarketStateType = market.copy() if market != null else null
	var result: EffectBatchResultType = system.settle_month(company, compute, market)
	return (
		result != null
		and not result.is_successful()
		and result.get_error_code() == expected_error_code
		and result.get_contributions().is_empty()
		and (
			company == null
			or (
				company.get_cash_cents() == cash_before
				and company.get_monthly_revenue_cents() == revenue_before
				and company.get_monthly_operating_cost_cents() == cost_before
			)
		)
		and (compute == null or _compute_states_equal(compute, compute_before))
		and (market == null or _market_states_equal(market, market_before))
	)


static func _market_fields_match(state: MarketStateType, expected: Array) -> bool:
	return (
		state != null
		and expected.size() == 19
		and state.get_consumer_workload_units_per_month() == expected[0]
		and state.get_developer_api_workload_units_per_month() == expected[1]
		and state.get_consumer_service_allocation_bps() == expected[2]
		and state.get_consumer_player_share_bps() == expected[3]
		and state.get_developer_api_player_share_bps() == expected[4]
		and state.get_consumer_addressable_monthly_revenue_cents() == expected[5]
		and state.get_developer_api_addressable_monthly_revenue_cents() == expected[6]
		and state.get_consumer_full_service_growth_bps() == expected[7]
		and state.get_developer_api_full_service_growth_bps() == expected[8]
		and state.get_consumer_unmet_penalty_bps_per_unit() == expected[9]
		and state.get_developer_api_unmet_penalty_bps_per_unit() == expected[10]
		and state.get_consumer_current_served_units_per_month() == expected[11]
		and state.get_developer_api_current_served_units_per_month() == expected[12]
		and state.get_consumer_current_market_revenue_cents() == expected[13]
		and state.get_developer_api_current_market_revenue_cents() == expected[14]
		and state.get_consumer_cumulative_served_compute_unit_months() == expected[15]
		and state.get_consumer_cumulative_unmet_compute_unit_months() == expected[16]
		and state.get_developer_api_cumulative_served_compute_unit_months() == expected[17]
		and state.get_developer_api_cumulative_unmet_compute_unit_months() == expected[18]
	)


static func _market_states_equal(first: MarketStateType, second: MarketStateType) -> bool:
	if first == null or second == null:
		return first == second
	return _market_fields_match(second, [
		first.get_consumer_workload_units_per_month(),
		first.get_developer_api_workload_units_per_month(),
		first.get_consumer_service_allocation_bps(),
		first.get_consumer_player_share_bps(),
		first.get_developer_api_player_share_bps(),
		first.get_consumer_addressable_monthly_revenue_cents(),
		first.get_developer_api_addressable_monthly_revenue_cents(),
		first.get_consumer_full_service_growth_bps(),
		first.get_developer_api_full_service_growth_bps(),
		first.get_consumer_unmet_penalty_bps_per_unit(),
		first.get_developer_api_unmet_penalty_bps_per_unit(),
		first.get_consumer_current_served_units_per_month(),
		first.get_developer_api_current_served_units_per_month(),
		first.get_consumer_current_market_revenue_cents(),
		first.get_developer_api_current_market_revenue_cents(),
		first.get_consumer_cumulative_served_compute_unit_months(),
		first.get_consumer_cumulative_unmet_compute_unit_months(),
		first.get_developer_api_cumulative_served_compute_unit_months(),
		first.get_developer_api_cumulative_unmet_compute_unit_months(),
	])


static func _compute_states_equal(first: ComputeStateType, second: ComputeStateType) -> bool:
	if first == null or second == null:
		return first == second
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
		and _compute_states_equal(first.get_compute(), second.get_compute())
		and _market_states_equal(first.get_market(), second.get_market())
	)


static func _market_effect_matches(
	effect: EffectContributionType,
	subject: StringName,
	reason: StringName,
	delta: int
) -> bool:
	var expected_metric: StringName
	var expected_unit: int
	match reason:
		EffectContributionType.REASON_MARKET_SERVED:
			expected_metric = (
				EffectContributionType.METRIC_CUMULATIVE_MARKET_SERVED_COMPUTE_UNIT_MONTHS
			)
			expected_unit = EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
		EffectContributionType.REASON_MARKET_UNMET:
			expected_metric = (
				EffectContributionType.METRIC_CUMULATIVE_MARKET_UNMET_COMPUTE_UNIT_MONTHS
			)
			expected_unit = EffectContributionType.Unit.COMPUTE_UNIT_MONTHS
		EffectContributionType.REASON_MARKET_SHARE_CHANGE:
			expected_metric = EffectContributionType.METRIC_PLAYER_SHARE_BPS
			expected_unit = EffectContributionType.Unit.BASIS_POINTS
		EffectContributionType.REASON_MARKET_REVENUE_CHANGE:
			expected_metric = EffectContributionType.METRIC_MARKET_MONTHLY_REVENUE_CENTS
			expected_unit = EffectContributionType.Unit.CENTS
		_:
			return false
	return (
		effect != null
		and effect.get_source_key() == EffectContributionType.SOURCE_MARKET
		and effect.get_subject_key() == subject
		and effect.get_reason_key() == reason
		and effect.get_metric_key() == expected_metric
		and effect.get_unit() == expected_unit
		and effect.get_delta() == delta
	)


static func _sum_market_delta(
	trace: Array[EffectContributionType],
	subject: StringName,
	reason: StringName
) -> int:
	var total: int = 0
	for contribution in trace:
		if (
			contribution.get_source_key() == EffectContributionType.SOURCE_MARKET
			and contribution.get_subject_key() == subject
			and contribution.get_reason_key() == reason
		):
			total += contribution.get_delta()
	return total


static func _append(
	target: Array[EffectContributionType],
	source: Array[EffectContributionType]
) -> void:
	for contribution in source:
		target.append(contribution)


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
