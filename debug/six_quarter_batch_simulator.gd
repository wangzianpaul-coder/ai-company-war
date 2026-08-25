class_name SixQuarterBatchSimulator
extends RefCounted


const BatchResultType = preload("res://debug/six_quarter_batch_result.gd")
const GameSessionType = preload("res://application/game_session.gd")
const StartProjectCommandType = preload(
	"res://simulation/commands/start_project_command.gd"
)
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const AdvanceQuarterCommandType = preload(
	"res://simulation/commands/advance_quarter_command.gd"
)
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")
const OpponentPersonalityType = preload(
	"res://simulation/ai/opponent_personality.gd"
)
const QuarterReportType = preload("res://simulation/reports/quarter_report.gd")

const CANONICAL_VERSION: String = "acw-tp023-batch-v1"
const POLICY_TRAINING_FIRST: StringName = &"training_first"
const POLICY_INFERENCE_FIRST: StringName = &"inference_first"
const PROJECT_ID: StringName = &"project_alpha"
const EXPECTED_GAMES: int = 100
const EXPECTED_QUARTERS: int = 600
const EXPECTED_REPORTS: int = 600
const EXPECTED_START_COMMANDS: int = 100
const EXPECTED_SET_COMMANDS: int = 600
const EXPECTED_ADVANCE_COMMANDS: int = 600
const EXPECTED_GAMES_PER_POLICY: int = 50
const QUARTERS_PER_GAME: int = 6
const MONTHS_PER_QUARTER: int = 3
const EXPECTED_ELAPSED_MONTHS: int = 18
const EXPECTED_PLAYER_TRAINING_TOTAL: int = 780
const EXPECTED_PLAYER_SERVED_TOTAL: int = 720
const EXPECTED_PLAYER_UNMET_TOTAL: int = 180


class RunOutcome:
	extends RefCounted

	var ordinal: int
	var policy_key: StringName
	var seed: int
	var successful_quarters: int = 0
	var start_command_count: int = 0
	var set_command_count: int = 0
	var advance_command_count: int = 0
	var reports: Array[QuarterReportType] = []
	var final_state: GameStateType
	var event_stream_unchanged: bool = false
	var market_stream_unchanged: bool = false
	var error_keys: Array[StringName] = []

	func _init(p_ordinal: int, p_policy_key: StringName, p_seed: int) -> void:
		ordinal = p_ordinal
		policy_key = p_policy_key
		seed = p_seed

	func add_error(error_key: StringName) -> void:
		if error_key != &"" and not error_keys.has(error_key):
			error_keys.append(error_key)

	func is_successful() -> bool:
		return error_keys.is_empty()

	func get_primary_error_key() -> StringName:
		return &"" if error_keys.is_empty() else error_keys[0]


## Executes the fixed policy/seed matrix only through fresh GameSession instances.
func run(inject_failure: bool = false) -> BatchResultType:
	var canonical_lines: Array[String] = [CANONICAL_VERSION]
	var errors: Array[String] = []
	var game_count: int = 0
	var quarter_count: int = 0
	var report_count: int = 0
	var failure_count: int = 0
	var training_first_game_count: int = 0
	var inference_first_game_count: int = 0
	var start_command_count: int = 0
	var set_command_count: int = 0
	var advance_command_count: int = 0
	var events_unchanged_game_count: int = 0
	var market_unchanged_game_count: int = 0
	var ordinal: int = 0

	var policy_keys: Array[StringName] = [
		POLICY_TRAINING_FIRST,
		POLICY_INFERENCE_FIRST,
	]
	for policy_key in policy_keys:
		var schedule: Array[int] = _schedule_for_policy(policy_key)
		for seed in range(1, EXPECTED_GAMES_PER_POLICY + 1):
			ordinal += 1
			game_count += 1
			if policy_key == POLICY_TRAINING_FIRST:
				training_first_game_count += 1
			else:
				inference_first_game_count += 1

			var outcome: RunOutcome = _execute_game(
				ordinal,
				policy_key,
				seed,
				schedule
			)
			start_command_count += outcome.start_command_count
			set_command_count += outcome.set_command_count
			advance_command_count += outcome.advance_command_count
			quarter_count += outcome.successful_quarters
			report_count += outcome.reports.size()
			if outcome.event_stream_unchanged:
				events_unchanged_game_count += 1
			if outcome.market_stream_unchanged:
				market_unchanged_game_count += 1

			# The injected path marks one otherwise complete run as failed. It never
			# alters commands, reports, state, RNG, policy order, or canonical fields.
			if inject_failure and ordinal == 1:
				outcome.add_error(&"injected_failure")

			var report_lines: Array[String] = []
			for report_index in outcome.reports.size():
				var report: QuarterReportType = outcome.reports[report_index]
				if not _report_keys_are_canonical(report):
					outcome.add_error(&"invalid_report_key")
				var report_line: String = _build_report_line(outcome.ordinal, report)
				if report_line.is_empty():
					outcome.add_error(&"invalid_report_encoding")
				else:
					report_lines.append(report_line)

			if not outcome.is_successful():
				failure_count += 1
			for error_key in outcome.error_keys:
				errors.append(
					"run_%d_%s_seed_%d_%s" % [
						outcome.ordinal,
						String(outcome.policy_key),
						outcome.seed,
						String(error_key),
					]
				)

			canonical_lines.append(_build_run_line(outcome))
			for report_line in report_lines:
				canonical_lines.append(report_line)

	_validate_aggregate_counts(
		game_count,
		quarter_count,
		report_count,
		training_first_game_count,
		inference_first_game_count,
		start_command_count,
		set_command_count,
		advance_command_count,
		events_unchanged_game_count,
		market_unchanged_game_count,
		errors
	)
	if not errors.is_empty() and failure_count == 0:
		failure_count = 1

	var aggregate_line: String = "aggregate|%d|%d|%d|%d|%d|%d" % [
		game_count,
		quarter_count,
		report_count,
		failure_count,
		training_first_game_count,
		inference_first_game_count,
	]
	canonical_lines.append(aggregate_line)
	var canonical_text: String = "\n".join(canonical_lines) + "\n"
	var digest: String = _sha256(canonical_text)
	if digest.length() != 64 or not _is_lower_hex(digest):
		errors.append("sha256_failed")
		if failure_count == 0:
			failure_count = 1

	var successful: bool = (
		errors.is_empty()
		and failure_count == 0
		and game_count == EXPECTED_GAMES
		and quarter_count == EXPECTED_QUARTERS
		and report_count == EXPECTED_REPORTS
		and training_first_game_count == EXPECTED_GAMES_PER_POLICY
		and inference_first_game_count == EXPECTED_GAMES_PER_POLICY
		and start_command_count == EXPECTED_START_COMMANDS
		and set_command_count == EXPECTED_SET_COMMANDS
		and advance_command_count == EXPECTED_ADVANCE_COMMANDS
		and events_unchanged_game_count == EXPECTED_GAMES
		and market_unchanged_game_count == EXPECTED_GAMES
	)
	return BatchResultType.new(
		successful,
		game_count,
		quarter_count,
		report_count,
		failure_count,
		training_first_game_count,
		inference_first_game_count,
		start_command_count,
		set_command_count,
		advance_command_count,
		events_unchanged_game_count,
		market_unchanged_game_count,
		canonical_text,
		canonical_lines,
		digest,
		aggregate_line,
		errors
	)


func _execute_game(
	ordinal: int,
	policy_key: StringName,
	seed: int,
	schedule: Array[int]
) -> RunOutcome:
	var outcome: RunOutcome = RunOutcome.new(ordinal, policy_key, seed)
	if schedule.size() != QUARTERS_PER_GAME:
		outcome.add_error(&"invalid_policy_schedule")
		return outcome
	var initial_state: GameStateType = _create_canonical_state(seed)
	var personality: OpponentPersonalityType = _create_personality()
	if initial_state == null or personality == null:
		outcome.add_error(&"invalid_fixture")
		return outcome
	var initial_rng: NamedRngStateType = initial_state.get_named_rng()
	if (
		initial_rng == null
		or initial_rng.get_ai_stream_state() != seed
		or initial_rng.get_events_stream_state() != seed + 4
		or initial_rng.get_market_stream_state() != seed + 6
	):
		outcome.add_error(&"invalid_named_stream_fixture")
		return outcome
	var initial_events_state: int = initial_rng.get_events_stream_state()
	var initial_market_state: int = initial_rng.get_market_stream_state()
	var session: GameSessionType = GameSessionType.new(initial_state, personality)

	outcome.start_command_count += 1
	var start_result = session.submit_command(StartProjectCommandType.new())
	if start_result == null or not start_result.is_successful():
		outcome.add_error(&"start_command_rejected")
		outcome.final_state = session.get_state_snapshot()
		_update_stream_flags(outcome, initial_events_state, initial_market_state)
		return outcome
	if (
		session.get_prototype_quarter_count() != 0
		or not session.get_quarter_reports().is_empty()
		or session.is_prototype_complete()
	):
		outcome.add_error(&"start_changed_prototype_history")

	for quarter_index in QUARTERS_PER_GAME:
		var history_before_set: Array = session.get_quarter_reports()
		outcome.set_command_count += 1
		var set_result = session.submit_command(
			SetComputeAllocationCommandType.new(schedule[quarter_index])
		)
		if set_result == null or not set_result.is_successful():
			outcome.add_error(&"set_command_rejected")
			break
		if session.get_quarter_reports().size() != history_before_set.size():
			outcome.add_error(&"set_changed_report_history")
			break

		outcome.advance_command_count += 1
		var advance_result = session.submit_command(AdvanceQuarterCommandType.new())
		if advance_result == null or not advance_result.is_successful():
			outcome.add_error(&"advance_command_rejected")
			break
		outcome.successful_quarters += 1
		var published_reports: Array = session.get_quarter_reports()
		if (
			session.get_prototype_quarter_count() != outcome.successful_quarters
			or published_reports.size() != outcome.successful_quarters
			or session.get_state_snapshot().get_clock().get_elapsed_months()
				!= outcome.successful_quarters * MONTHS_PER_QUARTER
		):
			outcome.add_error(&"quarter_publication_mismatch")
			break

	outcome.reports.clear()
	for published_report in session.get_quarter_reports():
		if published_report == null or not (published_report is QuarterReportType):
			outcome.add_error(&"invalid_report_type")
		else:
			outcome.reports.append(published_report as QuarterReportType)
	outcome.final_state = session.get_state_snapshot()
	_validate_completed_game(session, outcome, schedule)
	_update_stream_flags(outcome, initial_events_state, initial_market_state)
	if not outcome.event_stream_unchanged:
		outcome.add_error(&"events_stream_changed")
	if not outcome.market_stream_unchanged:
		outcome.add_error(&"market_stream_changed")
	return outcome


func _validate_completed_game(
	session: GameSessionType,
	outcome: RunOutcome,
	schedule: Array[int]
) -> void:
	if outcome.successful_quarters != QUARTERS_PER_GAME:
		outcome.add_error(&"quarter_count_mismatch")
	if outcome.reports.size() != QUARTERS_PER_GAME:
		outcome.add_error(&"report_count_mismatch")
	if session.get_prototype_quarter_count() != QUARTERS_PER_GAME:
		outcome.add_error(&"prototype_count_mismatch")
	if not session.is_prototype_complete():
		outcome.add_error(&"prototype_incomplete")
	var state: GameStateType = outcome.final_state
	if state == null:
		outcome.add_error(&"missing_terminal_state")
		return
	if state.get_clock().get_elapsed_months() != EXPECTED_ELAPSED_MONTHS:
		outcome.add_error(&"elapsed_months_mismatch")
	var company: CompanyStateType = state.get_company()
	var project: ProjectStateType = state.get_project()
	if (
		company == null
		or company.get_monthly_revenue_cents() < 0
		or company.get_monthly_operating_cost_cents() < 0
	):
		outcome.add_error(&"company_invariant_failed")
	if (
		project == null
		or project.get_project_id() != PROJECT_ID
		or project.get_lifecycle() != ProjectStateType.Lifecycle.COMPLETED
		or project.get_required_months() != 3
		or project.get_progress_months() != 3
	):
		outcome.add_error(&"project_completion_failed")
	var compute: ComputeStateType = state.get_compute()
	if (
		compute == null
		or compute.get_total_units_per_month() != 100
		or compute.get_reserve_units_per_month() != 10
		or compute.get_training_allocation_units_per_month()
			+ compute.get_inference_allocation_units_per_month()
			+ compute.get_reserve_units_per_month()
			!= compute.get_total_units_per_month()
		or compute.get_cumulative_training_compute_unit_months()
			!= EXPECTED_PLAYER_TRAINING_TOTAL
		or compute.get_cumulative_served_inference_compute_unit_months()
			!= EXPECTED_PLAYER_SERVED_TOTAL
		or compute.get_cumulative_unmet_inference_compute_unit_months()
			!= EXPECTED_PLAYER_UNMET_TOTAL
	):
		outcome.add_error(&"compute_invariant_failed")
	var expected_training: int = 0
	for allocation in schedule:
		expected_training += allocation * MONTHS_PER_QUARTER
	if expected_training != EXPECTED_PLAYER_TRAINING_TOTAL:
		outcome.add_error(&"policy_training_total_mismatch")
	_validate_market(state.get_market(), outcome)
	_validate_reports(outcome.reports, outcome)
	var rng_state: NamedRngStateType = state.get_named_rng()
	if (
		rng_state == null
		or not rng_state.is_valid_active_version_one()
		or rng_state.get_master_seed() != outcome.seed
	):
		outcome.add_error(&"named_rng_invariant_failed")


func _validate_market(market: MarketStateType, outcome: RunOutcome) -> void:
	if market == null:
		outcome.add_error(&"missing_market_state")
		return
	var shares_valid: bool = (
		market.get_consumer_player_share_bps() >= 0
		and market.get_consumer_player_share_bps() <= MarketStateType.TOTAL_BASIS_POINTS
		and market.get_developer_api_player_share_bps() >= 0
		and market.get_developer_api_player_share_bps()
			<= MarketStateType.TOTAL_BASIS_POINTS
		and market.get_consumer_player_share_bps()
			+ market.get_consumer_outside_share_bps()
			== MarketStateType.TOTAL_BASIS_POINTS
		and market.get_developer_api_player_share_bps()
			+ market.get_developer_api_outside_share_bps()
			== MarketStateType.TOTAL_BASIS_POINTS
	)
	if not shares_valid:
		outcome.add_error(&"share_invariant_failed")
	var workload_valid: bool = (
		market.get_consumer_cumulative_served_compute_unit_months()
			+ market.get_consumer_cumulative_unmet_compute_unit_months()
			== market.get_consumer_workload_units_per_month() * EXPECTED_ELAPSED_MONTHS
		and market.get_developer_api_cumulative_served_compute_unit_months()
			+ market.get_developer_api_cumulative_unmet_compute_unit_months()
			== market.get_developer_api_workload_units_per_month()
				* EXPECTED_ELAPSED_MONTHS
		and market.get_consumer_current_market_revenue_cents() >= 0
		and market.get_developer_api_current_market_revenue_cents() >= 0
	)
	if not workload_valid:
		outcome.add_error(&"market_workload_invariant_failed")


func _validate_reports(
	reports: Array[QuarterReportType],
	outcome: RunOutcome
) -> void:
	var metric_keys: Array[StringName] = _metric_keys()
	var previous: QuarterReportType = null
	for report_index in reports.size():
		var current: QuarterReportType = reports[report_index]
		var expected_quarter: int = report_index + 1
		if current == null or not current.is_valid():
			outcome.add_error(&"invalid_report")
			continue
		if (
			current.get_quarter_number() != expected_quarter
			or current.get_start_elapsed_months() != report_index * MONTHS_PER_QUARTER
			or current.get_end_elapsed_months() != expected_quarter * MONTHS_PER_QUARTER
		):
			outcome.add_error(&"report_boundary_mismatch")
		if expected_quarter < QUARTERS_PER_GAME:
			if not current.has_next_signal() or current.is_prototype_complete():
				outcome.add_error(&"missing_next_signal")
		elif current.has_next_signal() or not current.is_prototype_complete():
			outcome.add_error(&"quarter_six_next_signal_present")
		if previous != null:
			for metric_key in metric_keys:
				if (
					previous.get_after_value(metric_key)
					!= current.get_before_value(metric_key)
				):
					outcome.add_error(&"report_chain_mismatch")
					break
		previous = current


func _update_stream_flags(
	outcome: RunOutcome,
	initial_events_state: int,
	initial_market_state: int
) -> void:
	if outcome.final_state == null or outcome.final_state.get_named_rng() == null:
		return
	var final_rng: NamedRngStateType = outcome.final_state.get_named_rng()
	outcome.event_stream_unchanged = (
		final_rng.get_events_stream_state() == initial_events_state
	)
	outcome.market_stream_unchanged = (
		final_rng.get_market_stream_state() == initial_market_state
	)


func _build_run_line(outcome: RunOutcome) -> String:
	var state: GameStateType = outcome.final_state
	if state == null:
		state = GameStateType.new()
	var company: CompanyStateType = state.get_company()
	var compute: ComputeStateType = state.get_compute()
	var market: MarketStateType = state.get_market()
	var rng_state: NamedRngStateType = state.get_named_rng()
	var status: String = "ok" if outcome.is_successful() else "error"
	var error_text: String = "-"
	if not outcome.is_successful():
		error_text = _encode_key(outcome.get_primary_error_key())
	return "|".join([
		"run",
		str(outcome.ordinal),
		_encode_key(outcome.policy_key),
		str(outcome.seed),
		status,
		error_text,
		str(outcome.successful_quarters),
		str(outcome.reports.size()),
		str(state.get_clock().get_elapsed_months()),
		str(company.get_cash_cents()),
		str(company.get_monthly_revenue_cents()),
		str(compute.get_cumulative_training_compute_unit_months()),
		str(compute.get_cumulative_served_inference_compute_unit_months()),
		str(compute.get_cumulative_unmet_inference_compute_unit_months()),
		str(market.get_consumer_player_share_bps()),
		str(market.get_consumer_current_market_revenue_cents()),
		str(market.get_developer_api_player_share_bps()),
		str(market.get_developer_api_current_market_revenue_cents()),
		str(rng_state.get_ai_stream_state()),
		str(rng_state.get_events_stream_state()),
		str(rng_state.get_market_stream_state()),
	])


func _build_report_line(run_ordinal: int, report: QuarterReportType) -> String:
	if report == null:
		return ""
	var next_candidate: String = "-"
	var next_training: String = "-"
	var next_reason: String = "-"
	if report.has_next_signal():
		next_candidate = _encode_key(report.get_next_candidate_key())
		next_training = str(report.get_next_training_units_per_month())
		next_reason = _encode_key(report.get_next_reason_key())
	var displayed_reasons: String = _encode_reason_keys(
		report.get_all_displayed_reason_keys()
	)
	return "|".join([
		"report",
		str(run_ordinal),
		str(report.get_quarter_number()),
		str(report.get_start_elapsed_months()),
		str(report.get_end_elapsed_months()),
		str(report.get_before_value(QuarterReportType.METRIC_CASH_CENTS)),
		str(report.get_after_value(QuarterReportType.METRIC_CASH_CENTS)),
		str(report.get_before_value(
			QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS
		)),
		str(report.get_before_value(
			QuarterReportType.METRIC_CONSUMER_PLAYER_SHARE_BPS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_CONSUMER_PLAYER_SHARE_BPS
		)),
		str(report.get_before_value(
			QuarterReportType.METRIC_CONSUMER_MONTHLY_REVENUE_CENTS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_CONSUMER_MONTHLY_REVENUE_CENTS
		)),
		str(report.get_before_value(
			QuarterReportType.METRIC_DEVELOPER_API_PLAYER_SHARE_BPS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_DEVELOPER_API_PLAYER_SHARE_BPS
		)),
		str(report.get_before_value(
			QuarterReportType.METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS
		)),
		str(report.get_before_value(
			QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS
		)),
		str(report.get_before_value(
			QuarterReportType.METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
		)),
		str(report.get_before_value(
			QuarterReportType.METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
		)),
		str(report.get_after_value(
			QuarterReportType.METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
		)),
		_encode_key(report.get_committed_candidate_key()),
		str(report.get_committed_training_units_per_month()),
		_encode_key(report.get_committed_reason_key()),
		str(report.get_committed_base_utility_points()),
		str(report.get_committed_noise_points()),
		str(report.get_committed_total_utility_points()),
		next_candidate,
		next_training,
		next_reason,
		displayed_reasons,
	])


func _report_keys_are_canonical(report: QuarterReportType) -> bool:
	if report == null:
		return false
	if (
		not _is_key_text(String(report.get_committed_candidate_key()))
		or not _is_key_text(String(report.get_committed_reason_key()))
	):
		return false
	if report.has_next_signal() and (
		not _is_key_text(String(report.get_next_candidate_key()))
		or not _is_key_text(String(report.get_next_reason_key()))
	):
		return false
	for reason_key in report.get_all_displayed_reason_keys():
		if not _is_key_text(String(reason_key)):
			return false
	return true


func _validate_aggregate_counts(
	game_count: int,
	quarter_count: int,
	report_count: int,
	training_first_game_count: int,
	inference_first_game_count: int,
	start_command_count: int,
	set_command_count: int,
	advance_command_count: int,
	events_unchanged_game_count: int,
	market_unchanged_game_count: int,
	errors: Array[String]
) -> void:
	if game_count != EXPECTED_GAMES:
		errors.append("batch_game_count_mismatch")
	if quarter_count != EXPECTED_QUARTERS:
		errors.append("batch_quarter_count_mismatch")
	if report_count != EXPECTED_REPORTS:
		errors.append("batch_report_count_mismatch")
	if (
		training_first_game_count != EXPECTED_GAMES_PER_POLICY
		or inference_first_game_count != EXPECTED_GAMES_PER_POLICY
	):
		errors.append("batch_policy_count_mismatch")
	if (
		start_command_count != EXPECTED_START_COMMANDS
		or set_command_count != EXPECTED_SET_COMMANDS
		or advance_command_count != EXPECTED_ADVANCE_COMMANDS
	):
		errors.append("batch_command_count_mismatch")
	if (
		events_unchanged_game_count != EXPECTED_GAMES
		or market_unchanged_game_count != EXPECTED_GAMES
	):
		errors.append("batch_stream_invariant_failed")


func _create_canonical_state(seed: int) -> GameStateType:
	var rng_state: NamedRngStateType = NamedRngStateType.create_fresh_version_one(seed)
	if rng_state == null:
		return null
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		ProjectStateType.new(PROJECT_ID, 3, 25_000, 30_000),
		ComputeStateType.new(100, 10, 50, 40),
		MarketStateType.new(
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
			0,
			0,
			0,
			0,
			2,
			5
		),
		OpponentStateType.new(
			OpponentStateType.NORTHSTAR_LABS_ID,
			ComputeStateType.new(100, 10, 50, 40)
		),
		rng_state
	)


func _create_personality() -> OpponentPersonalityType:
	var candidates: Array[OpponentPersonalityType.Candidate] = [
		OpponentPersonalityType.Candidate.new(
			OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
			40,
			OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
			OpponentPersonalityType.UTILITY_RULE_DEFEND_MARKETS
		),
		OpponentPersonalityType.Candidate.new(
			OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP,
			70,
			OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP,
			OpponentPersonalityType.UTILITY_RULE_CLOSE_TRAINING_GAP
		),
	]
	return OpponentPersonalityType.new(
		OpponentStateType.NORTHSTAR_LABS_ID,
		"Northstar Labs",
		candidates,
		500,
		100,
		500,
		180
	)


func _schedule_for_policy(policy_key: StringName) -> Array[int]:
	if policy_key == POLICY_TRAINING_FIRST:
		return [70, 70, 40, 40, 20, 20]
	if policy_key == POLICY_INFERENCE_FIRST:
		return [20, 20, 40, 40, 70, 70]
	return []


func _metric_keys() -> Array[StringName]:
	return [
		QuarterReportType.METRIC_CASH_CENTS,
		QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS,
		QuarterReportType.METRIC_CONSUMER_PLAYER_SHARE_BPS,
		QuarterReportType.METRIC_CONSUMER_MONTHLY_REVENUE_CENTS,
		QuarterReportType.METRIC_DEVELOPER_API_PLAYER_SHARE_BPS,
		QuarterReportType.METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS,
		QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS,
		QuarterReportType.METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS,
		QuarterReportType.METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS,
	]


func _encode_key(value: StringName) -> String:
	var text: String = String(value)
	return text if _is_key_text(text) else "-"


func _encode_reason_keys(reason_keys: Array[StringName]) -> String:
	if reason_keys.is_empty():
		return "-"
	var encoded: Array[String] = []
	for reason_key in reason_keys:
		var text: String = String(reason_key)
		if not _is_key_text(text):
			return "-"
		encoded.append(text)
	return ",".join(encoded)


func _is_key_text(value: String) -> bool:
	if value.is_empty():
		return false
	for index in value.length():
		var code: int = value.unicode_at(index)
		if not (
			(code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or code == 95
		):
			return false
	return true


func _sha256(value: String) -> String:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(value.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()


func _is_lower_hex(value: String) -> bool:
	if value.is_empty():
		return false
	for index in value.length():
		var code: int = value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true
