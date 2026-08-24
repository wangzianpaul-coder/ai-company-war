class_name SimulationEngine
extends RefCounted


const GameStateType = preload("res://simulation/state/game_state.gd")
const ProjectSystemType = preload("res://simulation/systems/project_system.gd")
const ComputeSystemType = preload("res://simulation/systems/compute_system.gd")
const FinanceSystemType = preload("res://simulation/systems/finance_system.gd")
const MarketSystemType = preload("res://simulation/systems/market_system.gd")
const AiSystemType = preload("res://simulation/systems/ai_system.gd")
const OpponentPlanningSnapshotType = preload(
	"res://simulation/ai/opponent_planning_snapshot.gd"
)
const OpponentPersonalityType = preload("res://simulation/ai/opponent_personality.gd")
const OpponentDecisionType = preload("res://simulation/ai/opponent_decision.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")


## Starts the project on an independent working copy.
func start_project(input_state: GameStateType) -> TickResultType:
	if input_state == null:
		return _failed_result()
	var working_state: GameStateType = input_state.copy()
	if working_state == null:
		return _failed_result()

	var project_result: EffectBatchResultType = ProjectSystemType.new().start_project(
		working_state.get_project()
	)
	if not project_result.is_successful():
		return _failed_result()
	return TickResultType.new(working_state, project_result.get_contributions())


## Changes the training split on an independent working copy with no monthly effects.
func set_compute_allocation(
	input_state: GameStateType,
	training_units_per_month: int
) -> TickResultType:
	if input_state == null:
		return _failed_result()
	var working_state: GameStateType = input_state.copy()
	if working_state == null:
		return _failed_result()

	var allocation_result: EffectBatchResultType = ComputeSystemType.new().set_training_allocation(
		working_state.get_compute(),
		training_units_per_month
	)
	if not allocation_result.is_successful():
		return _failed_result()
	return TickResultType.new(working_state, allocation_result.get_contributions())


## Validates the complete active/inactive tuple without consuming or mutating it.
func is_opponent_boundary_valid(
	input_state: GameStateType,
	planning_snapshot: OpponentPlanningSnapshotType,
	personality: OpponentPersonalityType
) -> bool:
	if input_state == null or input_state.get_opponent() == null:
		return false
	if input_state.get_opponent().get_opponent_id() != &"":
		return _is_active_opponent_boundary_valid(
			input_state,
			planning_snapshot,
			personality
		)
	return personality == null and _is_canonical_inactive_opponent(input_state)


## Runs exactly three ordered months on an isolated copy.
func advance_quarter(
	input_state: GameStateType,
	planning_snapshot: OpponentPlanningSnapshotType = null,
	personality: OpponentPersonalityType = null
) -> TickResultType:
	if input_state == null:
		return _failed_result()
	var working_state: GameStateType = input_state.copy()
	if working_state == null:
		return _failed_result()

	var opponent: OpponentStateType = working_state.get_opponent()
	if opponent == null:
		return _failed_result()
	var opponent_is_active: bool = opponent.get_opponent_id() != &""
	if not is_opponent_boundary_valid(working_state, planning_snapshot, personality):
		return _failed_result()
	if opponent_is_active:
		var decision: OpponentDecisionType = AiSystemType.new().decide(
			planning_snapshot,
			opponent,
			personality,
			working_state.get_named_rng()
		)
		if decision == null or not decision.is_successful():
			return _failed_result()
		var opponent_command: SetComputeAllocationCommandType = decision.get_command()
		if (
			opponent_command == null
			or opponent_command.get_script() != SetComputeAllocationCommandType
		):
			return _failed_result()
		var opponent_allocation_result: EffectBatchResultType = (
			ComputeSystemType.new().set_training_allocation(
				opponent.get_compute(),
				opponent_command.get_training_units_per_month()
			)
		)
		if not opponent_allocation_result.is_successful():
			return _failed_result()
		opponent._commit_decision(
			decision.get_candidate_key(),
			opponent_command.get_training_units_per_month(),
			decision.get_reason_key(),
			decision.get_base_utility_points(),
			decision.get_noise_points(),
			decision.get_total_utility_points()
		)
		if not working_state._commit_named_rng(decision.get_proposed_rng_state()):
			return _failed_result()

	var project_system: ProjectSystemType = ProjectSystemType.new()
	var compute_system: ComputeSystemType = ComputeSystemType.new()
	var finance_system: FinanceSystemType = FinanceSystemType.new()
	var market_system: MarketSystemType = MarketSystemType.new()
	var contributions: Array[EffectContributionType] = []
	for _month_index in 3:
		var project_result: EffectBatchResultType = project_system.advance_month(
			working_state.get_company(),
			working_state.get_project()
		)
		if not project_result.is_successful():
			return _failed_result()
		_append_contributions(contributions, project_result.get_contributions())

		var compute_result: EffectBatchResultType = compute_system.advance_month(
			working_state.get_compute()
		)
		if not compute_result.is_successful():
			return _failed_result()
		_append_contributions(contributions, compute_result.get_contributions())

		if opponent_is_active:
			var opponent_compute_result: EffectBatchResultType = compute_system.advance_month(
				opponent.get_compute(),
				EffectContributionType.SUBJECT_NORTHSTAR_LABS
			)
			if not opponent_compute_result.is_successful():
				return _failed_result()
			_append_contributions(
				contributions,
				opponent_compute_result.get_contributions()
			)

		var finance_result: EffectBatchResultType = finance_system.settle_month(
			working_state.get_company()
		)
		if not finance_result.is_successful():
			return _failed_result()
		_append_contributions(contributions, finance_result.get_contributions())

		var market_result: EffectBatchResultType
		if opponent_is_active:
			market_result = market_system.settle_month(
				working_state.get_company(),
				working_state.get_compute(),
				working_state.get_market(),
				opponent.get_compute()
			)
		else:
			market_result = market_system.settle_month(
				working_state.get_company(),
				working_state.get_compute(),
				working_state.get_market()
			)
		if not market_result.is_successful():
			return _failed_result()
		_append_contributions(contributions, market_result.get_contributions())

		if not working_state.get_clock().advance_month():
			return _failed_result()

	return TickResultType.new(working_state, contributions)


func _is_active_opponent_boundary_valid(
	state: GameStateType,
	planning_snapshot: OpponentPlanningSnapshotType,
	personality: OpponentPersonalityType
) -> bool:
	if planning_snapshot == null or personality == null:
		return false
	var opponent: OpponentStateType = state.get_opponent()
	if opponent.get_opponent_id() != personality.get_opponent_id():
		return false
	if (
		planning_snapshot.get_elapsed_months() != state.get_clock().get_elapsed_months()
		or planning_snapshot.get_consumer_player_share_bps()
			!= state.get_market().get_consumer_player_share_bps()
		or planning_snapshot.get_developer_api_player_share_bps()
			!= state.get_market().get_developer_api_player_share_bps()
	):
		return false
	if not state.get_named_rng().is_valid_active_version_one():
		return false
	return (
		state.get_market().get_consumer_opponent_pressure_bps_per_served_unit() >= 0
		and state.get_market()
			.get_developer_api_opponent_pressure_bps_per_served_unit() >= 0
	)


func _is_canonical_inactive_opponent(state: GameStateType) -> bool:
	var opponent: OpponentStateType = state.get_opponent()
	var compute = opponent.get_compute()
	return (
		opponent.get_opponent_id() == &""
		and compute != null
		and compute.get_total_units_per_month() == 0
		and compute.get_reserve_units_per_month() == 0
		and compute.get_inference_workload_units_per_month() == 0
		and compute.get_training_allocation_units_per_month() == 0
		and compute.get_cumulative_training_compute_unit_months() == 0
		and compute.get_cumulative_served_inference_compute_unit_months() == 0
		and compute.get_cumulative_unmet_inference_compute_unit_months() == 0
		and opponent.get_last_candidate_key() == &""
		and opponent.get_last_training_units_per_month() == 0
		and opponent.get_last_reason_key() == &""
		and opponent.get_last_base_utility_points() == 0
		and opponent.get_last_noise_points() == 0
		and opponent.get_last_total_utility_points() == 0
		and state.get_named_rng() != null
		and state.get_named_rng().is_canonical_inactive()
		and state.get_market().get_consumer_opponent_pressure_bps_per_served_unit() == 0
		and state.get_market()
			.get_developer_api_opponent_pressure_bps_per_served_unit() == 0
	)


func _failed_result() -> TickResultType:
	var no_contributions: Array[EffectContributionType] = []
	return TickResultType.new(null, no_contributions)


func _append_contributions(
	target: Array[EffectContributionType],
	source: Array[EffectContributionType]
) -> void:
	for contribution in source:
		target.append(contribution)
