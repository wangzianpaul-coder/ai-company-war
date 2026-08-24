class_name AiSystem
extends RefCounted


const OpponentPlanningSnapshotType = preload(
	"res://simulation/ai/opponent_planning_snapshot.gd"
)
const OpponentPersonalityType = preload("res://simulation/ai/opponent_personality.gd")
const OpponentDecisionType = preload("res://simulation/ai/opponent_decision.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")
const VersionedRngType = preload("res://simulation/rng/versioned_rng.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const ComputeSystemType = preload("res://simulation/systems/compute_system.gd")
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807
const TOTAL_BASIS_POINTS: int = 10_000
const ACTIVE_TOTAL_UNITS_PER_MONTH: int = 100
const ACTIVE_RESERVE_UNITS_PER_MONTH: int = 10
const ACTIVE_INFERENCE_WORKLOAD_UNITS_PER_MONTH: int = 50


## Returns a non-mutating legal Utility decision and a proposed copied RNG state.
## Every structurally valid legal candidate consumes exactly one local AI draw.
func decide(
	snapshot: OpponentPlanningSnapshotType,
	opponent: OpponentStateType,
	personality: OpponentPersonalityType,
	rng_state: NamedRngStateType
) -> OpponentDecisionType:
	if (
		not _is_snapshot_valid(snapshot)
		or not _is_opponent_valid(opponent)
		or not _is_personality_valid(personality)
		or rng_state == null
		or not rng_state.is_valid_active_version_one()
	):
		return _failed(OpponentDecisionType.ErrorCode.INVALID_STATE)
	if opponent.get_opponent_id() != personality.get_opponent_id():
		return _failed(OpponentDecisionType.ErrorCode.INVALID_STATE)

	var candidates: Array[OpponentPersonalityType.Candidate] = personality.get_candidates()
	candidates.sort_custom(_candidate_key_less)
	var compute_system: ComputeSystemType = ComputeSystemType.new()
	var versioned_rng: VersionedRngType = VersionedRngType.new()
	var candidate_ai_state: int = rng_state.get_ai_stream_state()
	var has_winner: bool = false
	var winning_command: SetComputeAllocationCommandType
	var winning_candidate_key: StringName
	var winning_reason_key: StringName
	var winning_base: int = 0
	var winning_noise: int = 0
	var winning_total: int = 0

	for candidate in candidates:
		var command: SetComputeAllocationCommandType = SetComputeAllocationCommandType.new(
			candidate.get_training_units()
		)
		var compute_copy: ComputeStateType = opponent.get_compute().copy()
		var allocation_result = compute_system.set_training_allocation(
			compute_copy,
			command.get_training_units_per_month()
		)
		if not allocation_result.is_successful():
			continue

		var draw: VersionedRngType.DrawResult = versioned_rng.draw_noise(
			rng_state.get_algorithm_version(),
			candidate_ai_state
		)
		if not draw.is_successful():
			return _failed(OpponentDecisionType.ErrorCode.INVALID_STATE)
		candidate_ai_state = draw.get_next_state()
		var base: int = _calculate_base(candidate, snapshot, opponent, personality)
		if base < 0:
			return _failed(OpponentDecisionType.ErrorCode.ARITHMETIC_OVERFLOW)
		var noise: int = draw.get_noise()
		if base > MAX_SIGNED_INT - noise:
			return _failed(OpponentDecisionType.ErrorCode.ARITHMETIC_OVERFLOW)
		var total: int = base + noise
		if not has_winner or total > winning_total:
			has_winner = true
			winning_command = command
			winning_candidate_key = candidate.get_candidate_key()
			winning_reason_key = candidate.get_reason_key()
			winning_base = base
			winning_noise = noise
			winning_total = total

	if not has_winner:
		return _failed(OpponentDecisionType.ErrorCode.NO_LEGAL_CANDIDATE)
	var proposed_rng_state: NamedRngStateType = NamedRngStateType.create_checked_current(
		rng_state.get_master_seed(),
		rng_state.get_algorithm_version(),
		candidate_ai_state,
		rng_state.get_events_stream_state(),
		rng_state.get_market_stream_state()
	)
	if proposed_rng_state == null:
		return _failed(OpponentDecisionType.ErrorCode.INVALID_STATE)
	return OpponentDecisionType.new(
		OpponentDecisionType.ErrorCode.NONE,
		winning_command,
		winning_candidate_key,
		winning_reason_key,
		winning_base,
		winning_noise,
		winning_total,
		proposed_rng_state
	)


func _is_snapshot_valid(snapshot: OpponentPlanningSnapshotType) -> bool:
	return (
		snapshot != null
		and snapshot.get_elapsed_months() >= 0
		and snapshot.get_consumer_player_share_bps() >= 0
		and snapshot.get_consumer_player_share_bps() <= TOTAL_BASIS_POINTS
		and snapshot.get_developer_api_player_share_bps() >= 0
		and snapshot.get_developer_api_player_share_bps() <= TOTAL_BASIS_POINTS
	)


func _is_opponent_valid(opponent: OpponentStateType) -> bool:
	if opponent == null or opponent.get_opponent_id() != OpponentStateType.NORTHSTAR_LABS_ID:
		return false
	var compute: ComputeStateType = opponent.get_compute()
	if compute == null:
		return false
	if (
		compute.get_total_units_per_month() != ACTIVE_TOTAL_UNITS_PER_MONTH
		or compute.get_reserve_units_per_month() != ACTIVE_RESERVE_UNITS_PER_MONTH
		or compute.get_inference_workload_units_per_month()
			!= ACTIVE_INFERENCE_WORKLOAD_UNITS_PER_MONTH
		or compute.get_training_allocation_units_per_month() < 0
		or compute.get_training_allocation_units_per_month()
			> compute.get_allocatable_capacity_units_per_month()
		or compute.get_cumulative_training_compute_unit_months() < 0
		or compute.get_cumulative_served_inference_compute_unit_months() < 0
		or compute.get_cumulative_unmet_inference_compute_unit_months() < 0
	):
		return false
	return _is_decision_metadata_valid(opponent)


func _is_decision_metadata_valid(opponent: OpponentStateType) -> bool:
	var is_empty: bool = (
		opponent.get_last_candidate_key() == &""
		and opponent.get_last_training_units_per_month() == 0
		and opponent.get_last_reason_key() == &""
		and opponent.get_last_base_utility_points() == 0
		and opponent.get_last_noise_points() == 0
		and opponent.get_last_total_utility_points() == 0
	)
	if is_empty:
		return true
	if (
		opponent.get_last_candidate_key() == &""
		or opponent.get_last_reason_key() == &""
		or opponent.get_last_training_units_per_month() < 0
		or opponent.get_last_base_utility_points() < 0
		or opponent.get_last_noise_points() < 0
		or opponent.get_last_noise_points() >= VersionedRngType.NOISE_UPPER_BOUND
		or opponent.get_last_total_utility_points() < 0
		or opponent.get_last_base_utility_points()
			> MAX_SIGNED_INT - opponent.get_last_noise_points()
	):
		return false
	return (
		opponent.get_last_total_utility_points()
		== opponent.get_last_base_utility_points() + opponent.get_last_noise_points()
	)


func _is_personality_valid(personality: OpponentPersonalityType) -> bool:
	if personality == null:
		return false
	if (
		personality.get_opponent_id() != OpponentStateType.NORTHSTAR_LABS_ID
		or personality.get_display_name().is_empty()
		or personality.get_defend_base_points() < 0
		or personality.get_defend_share_divisor_bps() <= 0
		or personality.get_train_base_points() < 0
		or personality.get_training_target_compute_unit_months() < 0
	):
		return false
	var candidates: Array[OpponentPersonalityType.Candidate] = personality.get_candidates()
	if candidates.size() != 2:
		return false
	var saw_defend: bool = false
	var saw_train: bool = false
	for candidate in candidates:
		if candidate == null:
			return false
		match candidate.get_candidate_key():
			OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS:
				if saw_defend:
					return false
				saw_defend = true
				if (
					candidate.get_reason_key()
						!= OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION
					or candidate.get_utility_rule_key()
						!= OpponentPersonalityType.UTILITY_RULE_DEFEND_MARKETS
				):
					return false
			OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP:
				if saw_train:
					return false
				saw_train = true
				if (
					candidate.get_reason_key()
						!= OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP
					or candidate.get_utility_rule_key()
						!= OpponentPersonalityType.UTILITY_RULE_CLOSE_TRAINING_GAP
				):
					return false
			_:
				return false
	return saw_defend and saw_train


@warning_ignore("integer_division")
func _calculate_base(
	candidate: OpponentPersonalityType.Candidate,
	snapshot: OpponentPlanningSnapshotType,
	opponent: OpponentStateType,
	personality: OpponentPersonalityType
) -> int:
	match candidate.get_utility_rule_key():
		OpponentPersonalityType.UTILITY_RULE_DEFEND_MARKETS:
			var share_sum: int = (
				snapshot.get_consumer_player_share_bps()
				+ snapshot.get_developer_api_player_share_bps()
			)
			var share_points: int = share_sum / personality.get_defend_share_divisor_bps()
			if personality.get_defend_base_points() > MAX_SIGNED_INT - share_points:
				return -1
			return personality.get_defend_base_points() + share_points
		OpponentPersonalityType.UTILITY_RULE_CLOSE_TRAINING_GAP:
			var cumulative_training: int = (
				opponent.get_compute().get_cumulative_training_compute_unit_months()
			)
			var target: int = personality.get_training_target_compute_unit_months()
			var gap: int = target - cumulative_training if target > cumulative_training else 0
			if personality.get_train_base_points() > MAX_SIGNED_INT - gap:
				return -1
			return personality.get_train_base_points() + gap
	return -1


func _candidate_key_less(
	first: OpponentPersonalityType.Candidate,
	second: OpponentPersonalityType.Candidate
) -> bool:
	return String(first.get_candidate_key()) < String(second.get_candidate_key())


func _failed(error_code: OpponentDecisionType.ErrorCode) -> OpponentDecisionType:
	return OpponentDecisionType.new(error_code)
