extends RefCounted


const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const OpponentDecisionType = preload("res://simulation/ai/opponent_decision.gd")
const OpponentPersonalityType = preload("res://simulation/ai/opponent_personality.gd")
const OpponentPlanningSnapshotType = preload(
	"res://simulation/ai/opponent_planning_snapshot.gd"
)
const GameStateType = preload("res://simulation/state/game_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")
const VersionedRngType = preload("res://simulation/rng/versioned_rng.gd")
const AiSystemType = preload("res://simulation/systems/ai_system.gd")
const ComputeSystemType = preload("res://simulation/systems/compute_system.gd")
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807


static func run(report: Callable) -> void:
	_report(
		report,
		_test_state_snapshot_and_copy_ownership(),
		"TP-022 opponent state and observable snapshot preserve strict ownership"
	)
	_report(
		report,
		_test_named_rng_goldens(),
		"TP-022 named RNG matches exact versioned stream Goldens"
	)
	_report(
		report,
		_test_utility_legality_scoring_and_tie_break(),
		"TP-022 Utility legality scoring reason and tie-break are exact"
	)
	_report(
		report,
		_test_deterministic_100_case_sweep(),
		"TP-022 deterministic 100-case AI sweep stays legal and bounded"
	)
	_report(
		report,
		_test_invalid_inputs_are_atomic(),
		"TP-022 invalid AI inputs fail atomically without RNG consumption"
	)


static func _test_state_snapshot_and_copy_ownership() -> bool:
	var snapshot: OpponentPlanningSnapshotType = OpponentPlanningSnapshotType.new(
		6,
		3_018,
		1_910
	)
	var snapshot_copy: OpponentPlanningSnapshotType = snapshot.copy()
	if (
		snapshot_copy == null
		or snapshot_copy == snapshot
		or snapshot_copy.get_elapsed_months() != 6
		or snapshot_copy.get_consumer_player_share_bps() != 3_018
		or snapshot_copy.get_developer_api_player_share_bps() != 1_910
	):
		return false

	var input_candidates: Array[OpponentPersonalityType.Candidate] = [
		_create_defend_candidate(40),
		_create_train_candidate(70),
	]
	var personality: OpponentPersonalityType = OpponentPersonalityType.new(
		OpponentStateType.NORTHSTAR_LABS_ID,
		"Northstar Labs",
		input_candidates,
		500,
		100,
		500,
		180
	)
	input_candidates.clear()
	var returned_candidates: Array[OpponentPersonalityType.Candidate] = (
		personality.get_candidates()
	)
	if returned_candidates.size() != 2:
		return false
	returned_candidates.clear()
	var personality_owns_candidates: bool = (
		personality.get_candidates().size() == 2
		and personality.get_candidates()[0] != personality.get_candidates()[0]
	)
	if not personality_owns_candidates:
		return false

	var supplied_opponent: OpponentStateType = OpponentStateType.new(
		OpponentStateType.NORTHSTAR_LABS_ID,
		ComputeStateType.new(100, 10, 50, 40, 7, 8, 9),
		OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
		40,
		OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
		550,
		7,
		557
	)
	var supplied_rng: NamedRngStateType = NamedRngStateType.create_checked_current(
		7,
		1,
		1_278_240_558,
		11,
		13
	)
	var owned_state: GameStateType = GameStateType.new(
		null,
		null,
		null,
		null,
		supplied_opponent,
		supplied_rng
	)
	var copied_state: GameStateType = owned_state.copy()
	if (
		copied_state == null
		or copied_state.get_opponent() == owned_state.get_opponent()
		or copied_state.get_opponent().get_compute()
			== owned_state.get_opponent().get_compute()
		or copied_state.get_named_rng() == owned_state.get_named_rng()
		or not _opponents_equal(copied_state.get_opponent(), owned_state.get_opponent())
		or not _rng_equal(copied_state.get_named_rng(), owned_state.get_named_rng())
	):
		return false

	var compute_system: ComputeSystemType = ComputeSystemType.new()
	if (
		not compute_system.set_training_allocation(
			copied_state.get_opponent().get_compute(),
			70
		).is_successful()
		or not compute_system.advance_month(
			copied_state.get_opponent().get_compute()
		).is_successful()
		or not copied_state._commit_named_rng(
			NamedRngStateType.create_checked_current(7, 1, 518_142_577, 11, 13)
		)
	):
		return false
	copied_state.get_opponent()._commit_decision(
		OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP,
		70,
		OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP,
		680,
		8,
		688
	)
	var source_unchanged_after_copy: bool = (
		owned_state.get_opponent().get_compute()
			.get_training_allocation_units_per_month() == 40
		and owned_state.get_opponent().get_compute()
			.get_cumulative_training_compute_unit_months() == 7
		and owned_state.get_opponent().get_last_candidate_key()
			== OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS
		and owned_state.get_named_rng().get_ai_stream_state() == 1_278_240_558
	)
	if not source_unchanged_after_copy:
		return false

	if (
		not compute_system.set_training_allocation(
			owned_state.get_opponent().get_compute(),
			0
		).is_successful()
		or not compute_system.advance_month(
			owned_state.get_opponent().get_compute()
		).is_successful()
		or not owned_state._commit_named_rng(
			NamedRngStateType.create_checked_current(7, 1, 337_897, 11, 13)
		)
	):
		return false
	return (
		copied_state.get_opponent().get_compute()
			.get_training_allocation_units_per_month() == 70
		and copied_state.get_opponent().get_compute()
			.get_cumulative_training_compute_unit_months() == 77
		and copied_state.get_opponent().get_last_candidate_key()
			== OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP
		and copied_state.get_named_rng().get_ai_stream_state() == 518_142_577
		and GameStateType.new().get_opponent().get_opponent_id() == &""
		and _compute_is_zero(GameStateType.new().get_opponent().get_compute())
		and GameStateType.new().get_named_rng().is_canonical_inactive()
	)


static func _test_named_rng_goldens() -> bool:
	var inactive: NamedRngStateType = NamedRngStateType.new()
	var inactive_copy: NamedRngStateType = inactive.copy()
	var fresh: NamedRngStateType = NamedRngStateType.create_fresh_version_one(7)
	var wrapped: NamedRngStateType = NamedRngStateType.create_fresh_version_one(
		NamedRngStateType.MAX_ACTIVE_VALUE
	)
	var current: NamedRngStateType = NamedRngStateType.create_checked_current(
		7,
		1,
		1_278_240_558,
		23,
		29
	)
	if (
		inactive_copy == null
		or inactive_copy == inactive
		or not inactive_copy.is_canonical_inactive()
		or fresh == null
		or not _rng_fields_match(fresh, [7, 1, 7, 11, 13])
		or wrapped == null
		or not _rng_fields_match(
			wrapped,
			[NamedRngStateType.MAX_ACTIVE_VALUE, 1,
			NamedRngStateType.MAX_ACTIVE_VALUE, 4, 6]
		)
		or current == null
		or not _rng_fields_match(current, [7, 1, 1_278_240_558, 23, 29])
		or NamedRngStateType.create_fresh_version_one(0) != null
		or NamedRngStateType.create_fresh_version_one(2_147_483_647) != null
		or NamedRngStateType.create_checked_current(7, 2, 7, 11, 13) != null
		or NamedRngStateType.create_checked_current(7, 1, 0, 11, 13) != null
	):
		return false

	var rng: VersionedRngType = VersionedRngType.new()
	var first: VersionedRngType.DrawResult = rng.draw_noise(1, 7)
	var second: VersionedRngType.DrawResult = rng.draw_noise(
		1,
		first.get_next_state()
	)
	var third: VersionedRngType.DrawResult = rng.draw_noise(
		1,
		second.get_next_state()
	)
	var fourth: VersionedRngType.DrawResult = rng.draw_noise(
		1,
		third.get_next_state()
	)
	var invalid_version: VersionedRngType.DrawResult = rng.draw_noise(2, 7)
	var invalid_low: VersionedRngType.DrawResult = rng.draw_noise(1, 0)
	var invalid_high: VersionedRngType.DrawResult = rng.draw_noise(1, 2_147_483_647)
	return (
		first.is_successful()
		and first.get_next_state() == 337_897
		and first.get_noise() == 7
		and second.is_successful()
		and second.get_next_state() == 1_278_240_558
		and second.get_noise() == 8
		and third.is_successful()
		and third.get_next_state() == 449_829_614
		and third.get_noise() == 4
		and fourth.is_successful()
		and fourth.get_next_state() == 518_142_577
		and fourth.get_noise() == 7
		and not invalid_version.is_successful()
		and not invalid_low.is_successful()
		and not invalid_high.is_successful()
		and _rng_fields_match(fresh, [7, 1, 7, 11, 13])
	)


static func _test_utility_legality_scoring_and_tie_break() -> bool:
	var ai: AiSystemType = AiSystemType.new()
	var snapshot: OpponentPlanningSnapshotType = OpponentPlanningSnapshotType.new(
		0,
		3_000,
		2_000
	)
	var opponent: OpponentStateType = _create_active_opponent()
	var rng: NamedRngStateType = NamedRngStateType.create_fresh_version_one(7)
	var forward: OpponentDecisionType = ai.decide(
		snapshot,
		opponent,
		_create_personality(false),
		rng
	)
	var reversed: OpponentDecisionType = ai.decide(
		snapshot,
		opponent,
		_create_personality(true),
		rng
	)
	if (
		not _decision_matches(
			forward,
			OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP,
			70,
			OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP,
			680,
			8,
			688,
			1_278_240_558
		)
		or not _decisions_equal(forward, reversed)
		or not _rng_fields_match(rng, [7, 1, 7, 11, 13])
	):
		return false

	var filtered_personality: OpponentPersonalityType = _create_personality(
		false,
		91,
		70
	)
	var filtered: OpponentDecisionType = ai.decide(
		snapshot,
		opponent,
		filtered_personality,
		rng
	)
	if not _decision_matches(
		filtered,
		OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP,
		70,
		OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP,
		680,
		7,
		687,
		337_897
	):
		return false

	var tie_snapshot: OpponentPlanningSnapshotType = OpponentPlanningSnapshotType.new(
		0,
		0,
		0
	)
	var tie_personality: OpponentPersonalityType = _create_personality(
		true,
		40,
		70,
		500,
		100,
		500,
		180
	)
	var tie_opponent: OpponentStateType = _create_active_opponent(180)
	var tie_rng: NamedRngStateType = NamedRngStateType.create_checked_current(
		7,
		1,
		10,
		11,
		13
	)
	var tie_first_draw: VersionedRngType.DrawResult = VersionedRngType.new().draw_noise(
		1,
		10
	)
	var tie_second_draw: VersionedRngType.DrawResult = VersionedRngType.new().draw_noise(
		1,
		tie_first_draw.get_next_state()
	)
	var tie: OpponentDecisionType = ai.decide(
		tie_snapshot,
		tie_opponent,
		tie_personality,
		tie_rng
	)
	return (
		tie_first_draw.is_successful()
		and tie_first_draw.get_next_state() == 482_710
		and tie_first_draw.get_noise() == 0
		and tie_second_draw.is_successful()
		and tie_second_draw.get_next_state() == 1_826_057_940
		and tie_second_draw.get_noise() == 0
		and _decision_matches(
			tie,
			OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
			40,
			OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
			500,
			0,
			500,
			1_826_057_940
		)
	)


static func _test_deterministic_100_case_sweep() -> bool:
	var ai: AiSystemType = AiSystemType.new()
	var compute_system: ComputeSystemType = ComputeSystemType.new()
	for case_index in 100:
		var seed: int = case_index + 1
		var snapshot: OpponentPlanningSnapshotType = OpponentPlanningSnapshotType.new(
			case_index * 3,
			(case_index * 97) % 10_001,
			(case_index * 193) % 10_001
		)
		var cumulative_training: int = (case_index * 13) % 260
		var first_opponent: OpponentStateType = _create_active_opponent(
			cumulative_training
		)
		var second_opponent: OpponentStateType = _create_active_opponent(
			cumulative_training
		)
		var first_rng: NamedRngStateType = NamedRngStateType.create_fresh_version_one(
			seed
		)
		var second_rng: NamedRngStateType = first_rng.copy()
		var personality: OpponentPersonalityType = _create_personality(
			case_index % 2 == 1
		)
		var first: OpponentDecisionType = ai.decide(
			snapshot,
			first_opponent,
			personality,
			first_rng
		)
		var second: OpponentDecisionType = ai.decide(
			snapshot.copy(),
			second_opponent,
			personality,
			second_rng
		)
		if not first.is_successful() or not _decisions_equal(first, second):
			return false
		var command: SetComputeAllocationCommandType = first.get_command()
		var proposed: NamedRngStateType = first.get_proposed_rng_state()
		var compute_copy: ComputeStateType = first_opponent.get_compute().copy()
		if (
			command == null
			or command.get_script() != SetComputeAllocationCommandType
			or not [40, 70].has(command.get_training_units_per_month())
			or not compute_system.set_training_allocation(
				compute_copy,
				command.get_training_units_per_month()
			).is_successful()
			or first.get_noise_points() < 0
			or first.get_noise_points() >= 10
			or first.get_total_utility_points()
				!= first.get_base_utility_points() + first.get_noise_points()
			or proposed == null
			or not proposed.is_valid_active_version_one()
			or proposed.get_events_stream_state()
				!= first_rng.get_events_stream_state()
			or proposed.get_market_stream_state()
				!= first_rng.get_market_stream_state()
			or not _rng_equal(first_rng, second_rng)
			or not _opponents_equal(first_opponent, second_opponent)
			or first_opponent.get_compute()
				.get_training_allocation_units_per_month() != 40
		):
			return false
	return true


static func _test_invalid_inputs_are_atomic() -> bool:
	var ai: AiSystemType = AiSystemType.new()
	var valid_snapshot: OpponentPlanningSnapshotType = OpponentPlanningSnapshotType.new(
		0,
		3_000,
		2_000
	)
	var valid_opponent: OpponentStateType = _create_active_opponent()
	var valid_personality: OpponentPersonalityType = _create_personality(false)
	var valid_rng: NamedRngStateType = NamedRngStateType.create_fresh_version_one(7)
	var all_atomic: bool = true
	all_atomic = _failure_preserves_inputs(
		ai,
		null,
		valid_opponent,
		valid_personality,
		valid_rng,
		OpponentDecisionType.ErrorCode.INVALID_STATE
	) and all_atomic
	all_atomic = _failure_preserves_inputs(
		ai,
		valid_snapshot,
		null,
		valid_personality,
		valid_rng,
		OpponentDecisionType.ErrorCode.INVALID_STATE
	) and all_atomic
	all_atomic = _failure_preserves_inputs(
		ai,
		valid_snapshot,
		valid_opponent,
		null,
		valid_rng,
		OpponentDecisionType.ErrorCode.INVALID_STATE
	) and all_atomic
	all_atomic = _failure_preserves_inputs(
		ai,
		valid_snapshot,
		valid_opponent,
		valid_personality,
		null,
		OpponentDecisionType.ErrorCode.INVALID_STATE
	) and all_atomic

	for invalid_snapshot in [
		OpponentPlanningSnapshotType.new(-1, 3_000, 2_000),
		OpponentPlanningSnapshotType.new(0, -1, 2_000),
		OpponentPlanningSnapshotType.new(0, 10_001, 2_000),
		OpponentPlanningSnapshotType.new(0, 3_000, -1),
		OpponentPlanningSnapshotType.new(0, 3_000, 10_001),
	]:
		all_atomic = _failure_preserves_inputs(
			ai,
			invalid_snapshot,
			valid_opponent,
			valid_personality,
			valid_rng,
			OpponentDecisionType.ErrorCode.INVALID_STATE
		) and all_atomic

	var invalid_opponents: Array[OpponentStateType] = [
		OpponentStateType.new(&"", ComputeStateType.new(100, 10, 50, 40)),
		OpponentStateType.new(&"wrong", ComputeStateType.new(100, 10, 50, 40)),
		OpponentStateType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			ComputeStateType.new(99, 10, 50, 40)
		),
		OpponentStateType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			ComputeStateType.new(100, 10, 50, 40),
			OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
			40,
			OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
			550,
			7,
			556
		),
	]
	for invalid_opponent in invalid_opponents:
		all_atomic = _failure_preserves_inputs(
			ai,
			valid_snapshot,
			invalid_opponent,
			valid_personality,
			valid_rng,
			OpponentDecisionType.ErrorCode.INVALID_STATE
		) and all_atomic

	var wrong_id_personality: OpponentPersonalityType = _create_personality(false)
	var wrong_candidates: Array[OpponentPersonalityType.Candidate] = [
		_create_defend_candidate(40),
		_create_train_candidate(70),
	]
	wrong_id_personality = OpponentPersonalityType.new(
		&"wrong",
		"Wrong",
		wrong_candidates,
		500,
		100,
		500,
		180
	)
	var duplicate_candidates: Array[OpponentPersonalityType.Candidate] = [
		_create_defend_candidate(40),
		_create_defend_candidate(70),
	]
	var unknown_candidates: Array[OpponentPersonalityType.Candidate] = [
		OpponentPersonalityType.Candidate.new(
			&"unknown",
			40,
			OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
			OpponentPersonalityType.UTILITY_RULE_DEFEND_MARKETS
		),
		_create_train_candidate(70),
	]
	var unknown_rule_candidates: Array[OpponentPersonalityType.Candidate] = [
		OpponentPersonalityType.Candidate.new(
			OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
			40,
			OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
			&"unknown"
		),
		_create_train_candidate(70),
	]
	var invalid_personalities: Array[OpponentPersonalityType] = [
		wrong_id_personality,
		OpponentPersonalityType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			"",
			wrong_candidates,
			500,
			100,
			500,
			180
		),
		OpponentPersonalityType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			"Northstar Labs",
			wrong_candidates,
			500,
			0,
			500,
			180
		),
		OpponentPersonalityType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			"Northstar Labs",
			duplicate_candidates,
			500,
			100,
			500,
			180
		),
		OpponentPersonalityType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			"Northstar Labs",
			unknown_candidates,
			500,
			100,
			500,
			180
		),
		OpponentPersonalityType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			"Northstar Labs",
			unknown_rule_candidates,
			500,
			100,
			500,
			180
		),
	]
	for invalid_personality in invalid_personalities:
		all_atomic = _failure_preserves_inputs(
			ai,
			valid_snapshot,
			valid_opponent,
			invalid_personality,
			valid_rng,
			OpponentDecisionType.ErrorCode.INVALID_STATE
		) and all_atomic

	for invalid_rng in [
		NamedRngStateType.new(7, 0, 7, 11, 13),
		NamedRngStateType.new(7, 2, 7, 11, 13),
		NamedRngStateType.new(7, 1, 0, 11, 13),
		NamedRngStateType.new(7, 1, 7, 0, 13),
		NamedRngStateType.new(7, 1, 7, 11, 2_147_483_647),
	]:
		all_atomic = _failure_preserves_inputs(
			ai,
			valid_snapshot,
			valid_opponent,
			valid_personality,
			invalid_rng,
			OpponentDecisionType.ErrorCode.INVALID_STATE
		) and all_atomic

	var no_legal: OpponentPersonalityType = _create_personality(false, -1, 91)
	all_atomic = _failure_preserves_inputs(
		ai,
		valid_snapshot,
		valid_opponent,
		no_legal,
		valid_rng,
		OpponentDecisionType.ErrorCode.NO_LEGAL_CANDIDATE
	) and all_atomic

	var overflow: OpponentPersonalityType = _create_personality(
		false,
		40,
		70,
		MAX_SIGNED_INT,
		100,
		500,
		180
	)
	all_atomic = _failure_preserves_inputs(
		ai,
		valid_snapshot,
		valid_opponent,
		overflow,
		valid_rng,
		OpponentDecisionType.ErrorCode.ARITHMETIC_OVERFLOW
	) and all_atomic
	return all_atomic


static func _create_personality(
	reversed: bool,
	defend_training_units: int = 40,
	train_training_units: int = 70,
	defend_base_points: int = 500,
	defend_share_divisor_bps: int = 100,
	train_base_points: int = 500,
	training_target_compute_unit_months: int = 180
) -> OpponentPersonalityType:
	var candidates: Array[OpponentPersonalityType.Candidate] = [
		_create_defend_candidate(defend_training_units),
		_create_train_candidate(train_training_units),
	]
	if reversed:
		candidates.reverse()
	return OpponentPersonalityType.new(
		OpponentStateType.NORTHSTAR_LABS_ID,
		"Northstar Labs",
		candidates,
		defend_base_points,
		defend_share_divisor_bps,
		train_base_points,
		training_target_compute_unit_months
	)


static func _create_defend_candidate(
	training_units: int
) -> OpponentPersonalityType.Candidate:
	return OpponentPersonalityType.Candidate.new(
		OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
		training_units,
		OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
		OpponentPersonalityType.UTILITY_RULE_DEFEND_MARKETS
	)


static func _create_train_candidate(
	training_units: int
) -> OpponentPersonalityType.Candidate:
	return OpponentPersonalityType.Candidate.new(
		OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP,
		training_units,
		OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP,
		OpponentPersonalityType.UTILITY_RULE_CLOSE_TRAINING_GAP
	)


static func _create_active_opponent(
	cumulative_training: int = 0
) -> OpponentStateType:
	return OpponentStateType.new(
		OpponentStateType.NORTHSTAR_LABS_ID,
		ComputeStateType.new(100, 10, 50, 40, cumulative_training, 0, 0)
	)


static func _decision_matches(
	decision: OpponentDecisionType,
	candidate_key: StringName,
	training_units: int,
	reason_key: StringName,
	base_points: int,
	noise_points: int,
	total_points: int,
	proposed_ai_state: int
) -> bool:
	if decision == null or not decision.is_successful():
		return false
	var command: SetComputeAllocationCommandType = decision.get_command()
	var proposed_rng: NamedRngStateType = decision.get_proposed_rng_state()
	return (
		decision.get_error_code() == OpponentDecisionType.ErrorCode.NONE
		and command != null
		and command.get_script() == SetComputeAllocationCommandType
		and command.get_training_units_per_month() == training_units
		and decision.get_candidate_key() == candidate_key
		and decision.get_reason_key() == reason_key
		and decision.get_base_utility_points() == base_points
		and decision.get_noise_points() == noise_points
		and decision.get_total_utility_points() == total_points
		and proposed_rng != null
		and proposed_rng.get_ai_stream_state() == proposed_ai_state
		and proposed_rng.get_events_stream_state() == 11
		and proposed_rng.get_market_stream_state() == 13
	)


static func _decisions_equal(
	first: OpponentDecisionType,
	second: OpponentDecisionType
) -> bool:
	if first == null or second == null:
		return first == second
	if first.is_successful() != second.is_successful():
		return false
	if first.get_error_code() != second.get_error_code():
		return false
	if not first.is_successful():
		return true
	var first_command: SetComputeAllocationCommandType = first.get_command()
	var second_command: SetComputeAllocationCommandType = second.get_command()
	return (
		first_command != null
		and second_command != null
		and first_command.get_script() == SetComputeAllocationCommandType
		and second_command.get_script() == SetComputeAllocationCommandType
		and first_command.get_training_units_per_month()
			== second_command.get_training_units_per_month()
		and first.get_candidate_key() == second.get_candidate_key()
		and first.get_reason_key() == second.get_reason_key()
		and first.get_base_utility_points() == second.get_base_utility_points()
		and first.get_noise_points() == second.get_noise_points()
		and first.get_total_utility_points() == second.get_total_utility_points()
		and _rng_equal(
			first.get_proposed_rng_state(),
			second.get_proposed_rng_state()
		)
	)


static func _failure_preserves_inputs(
	ai: AiSystemType,
	snapshot: OpponentPlanningSnapshotType,
	opponent: OpponentStateType,
	personality: OpponentPersonalityType,
	rng_state: NamedRngStateType,
	expected_error: int
) -> bool:
	var opponent_before: OpponentStateType = null if opponent == null else opponent.copy()
	var rng_before: Array[int] = _rng_fields(rng_state)
	var decision: OpponentDecisionType = ai.decide(
		snapshot,
		opponent,
		personality,
		rng_state
	)
	return (
		decision != null
		and not decision.is_successful()
		and decision.get_error_code() == expected_error
		and decision.get_command() == null
		and decision.get_candidate_key() == &""
		and decision.get_reason_key() == &""
		and decision.get_base_utility_points() == 0
		and decision.get_noise_points() == 0
		and decision.get_total_utility_points() == 0
		and decision.get_proposed_rng_state() == null
		and (opponent == null or _opponents_equal(opponent, opponent_before))
		and _rng_fields(rng_state) == rng_before
	)


static func _compute_is_zero(compute: ComputeStateType) -> bool:
	return (
		compute != null
		and compute.get_total_units_per_month() == 0
		and compute.get_reserve_units_per_month() == 0
		and compute.get_inference_workload_units_per_month() == 0
		and compute.get_training_allocation_units_per_month() == 0
		and compute.get_cumulative_training_compute_unit_months() == 0
		and compute.get_cumulative_served_inference_compute_unit_months() == 0
		and compute.get_cumulative_unmet_inference_compute_unit_months() == 0
	)


static func _opponents_equal(
	first: OpponentStateType,
	second: OpponentStateType
) -> bool:
	if first == null or second == null:
		return first == second
	return (
		first.get_opponent_id() == second.get_opponent_id()
		and _compute_fields(first.get_compute()) == _compute_fields(second.get_compute())
		and first.get_last_candidate_key() == second.get_last_candidate_key()
		and first.get_last_training_units_per_month()
			== second.get_last_training_units_per_month()
		and first.get_last_reason_key() == second.get_last_reason_key()
		and first.get_last_base_utility_points()
			== second.get_last_base_utility_points()
		and first.get_last_noise_points() == second.get_last_noise_points()
		and first.get_last_total_utility_points()
			== second.get_last_total_utility_points()
	)


static func _compute_fields(compute: ComputeStateType) -> Array[int]:
	if compute == null:
		return []
	return [
		compute.get_total_units_per_month(),
		compute.get_reserve_units_per_month(),
		compute.get_inference_workload_units_per_month(),
		compute.get_training_allocation_units_per_month(),
		compute.get_cumulative_training_compute_unit_months(),
		compute.get_cumulative_served_inference_compute_unit_months(),
		compute.get_cumulative_unmet_inference_compute_unit_months(),
	]


static func _rng_equal(first: NamedRngStateType, second: NamedRngStateType) -> bool:
	return _rng_fields(first) == _rng_fields(second)


static func _rng_fields_match(rng_state: NamedRngStateType, expected: Array) -> bool:
	return _rng_fields(rng_state) == expected


static func _rng_fields(rng_state: NamedRngStateType) -> Array[int]:
	if rng_state == null:
		return []
	return [
		rng_state.get_master_seed(),
		rng_state.get_algorithm_version(),
		rng_state.get_ai_stream_state(),
		rng_state.get_events_stream_state(),
		rng_state.get_market_stream_state(),
	]


static func _report(report: Callable, condition: bool, description: String) -> void:
	report.call(condition, description)
