extends RefCounted


const StartProjectCommandType = preload(
	"res://simulation/commands/start_project_command.gd"
)
const AdvanceQuarterCommandType = preload(
	"res://simulation/commands/advance_quarter_command.gd"
)
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const GameStateType = preload("res://simulation/state/game_state.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const OpponentPersonalityType = preload(
	"res://simulation/ai/opponent_personality.gd"
)
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")
const EffectContributionType = preload(
	"res://simulation/events/effect_contribution.gd"
)
const QuarterReportType = preload("res://simulation/reports/quarter_report.gd")
const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload(
	"res://application/view_models/dashboard_view_model.gd"
)
const MAX_SIGNED_INT: int = 9_223_372_036_854_775_807


class SignalCounter:
	extends RefCounted

	var count: int = 0

	func capture(_view_model: DashboardViewModelType) -> void:
		count += 1


class PublicationObserver:
	extends RefCounted

	var count: int = 0
	var all_signals_saw_committed_values: bool = true
	var observed_report_counts: Array[int] = []
	var _session
	var _expected_report_count: int = -1
	var _expected_elapsed_months: int = -1
	var _expected_complete: bool = false

	func _init(p_session) -> void:
		_session = p_session

	func expect_commit(
		p_report_count: int,
		p_elapsed_months: int,
		p_complete: bool
	) -> void:
		_expected_report_count = p_report_count
		_expected_elapsed_months = p_elapsed_months
		_expected_complete = p_complete

	func capture(view_model: DashboardViewModelType) -> void:
		count += 1
		var snapshot: GameStateType = _session.get_state_snapshot()
		var reports: Array[QuarterReportType] = _session.get_quarter_reports()
		observed_report_counts.append(reports.size())
		var committed: bool = (
			snapshot != null
			and view_model != null
			and _session.get_current_view_model() == view_model
			and reports.size() == _expected_report_count
			and _session.get_prototype_quarter_count() == _expected_report_count
			and snapshot.get_clock().get_elapsed_months()
				== _expected_elapsed_months
			and _session.is_prototype_complete() == _expected_complete
			and view_model.get_quarter_report_count() == _expected_report_count
			and view_model.get_prototype_quarter_count()
				== _expected_report_count
			and view_model.is_prototype_complete() == _expected_complete
			and view_model.are_business_actions_enabled() != _expected_complete
		)
		for report_index in reports.size():
			var report: QuarterReportType = reports[report_index]
			committed = (
				committed
				and report != null
				and report.is_valid()
				and report.get_quarter_number() == report_index + 1
				and report.get_end_elapsed_months() == (report_index + 1) * 3
			)
		if not reports.is_empty():
			committed = committed and _latest_report_matches_state(
				reports[reports.size() - 1],
				snapshot
			)
		all_signals_saw_committed_values = (
			all_signals_saw_committed_values and committed
		)

	func _latest_report_matches_state(
		report: QuarterReportType,
		state: GameStateType
	) -> bool:
		return (
			report.get_after_value(QuarterReportType.METRIC_CASH_CENTS)
				== state.get_company().get_cash_cents()
			and report.get_after_value(
				QuarterReportType.METRIC_COMPANY_MONTHLY_REVENUE_CENTS
			) == state.get_company().get_monthly_revenue_cents()
			and report.get_after_value(
				QuarterReportType.METRIC_CONSUMER_PLAYER_SHARE_BPS
			) == state.get_market().get_consumer_player_share_bps()
			and report.get_after_value(
				QuarterReportType.METRIC_CONSUMER_MONTHLY_REVENUE_CENTS
			) == state.get_market().get_consumer_current_market_revenue_cents()
			and report.get_after_value(
				QuarterReportType.METRIC_DEVELOPER_API_PLAYER_SHARE_BPS
			) == state.get_market().get_developer_api_player_share_bps()
			and report.get_after_value(
				QuarterReportType.METRIC_DEVELOPER_API_MONTHLY_REVENUE_CENTS
			) == state.get_market().get_developer_api_current_market_revenue_cents()
			and report.get_after_value(
				QuarterReportType.METRIC_PLAYER_TRAINING_COMPUTE_UNIT_MONTHS
			) == state.get_compute().get_cumulative_training_compute_unit_months()
			and report.get_after_value(
				QuarterReportType.METRIC_PLAYER_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS
			) == state.get_compute().get_cumulative_served_inference_compute_unit_months()
			and report.get_after_value(
				QuarterReportType.METRIC_PLAYER_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS
			) == state.get_compute().get_cumulative_unmet_inference_compute_unit_months()
		)


static func run(report: Callable) -> void:
	_report(
		report,
		_test_six_quarter_golden_and_repeat(),
		"TP-023 six-quarter lifecycle advances exactly 18 months"
	)
	_report(
		report,
		_test_failed_and_completed_commands_are_atomic(),
		"TP-023 failed or seventh quarter preserves state reports and RNG"
	)
	_report(
		report,
		_test_publication_observer_and_history_copies(),
		"TP-023 GameSession publishes only committed report history"
	)


## Runner-owned scene check. The runner awaits this and reports its own sentinel.
## It starts from the runner's already committed Q1 and leaves Q6 details open.
static func validate_dashboard_report_history_scene(
	main_instance: Control,
	viewport: Window
) -> bool:
	if main_instance == null or viewport == null or main_instance.get_tree() == null:
		return false
	var prefix: NodePath = ^"DashboardMargin/Dashboard"
	var training_spin_box: SpinBox = main_instance.get_node_or_null(
		NodePath("%s/ComputePlanControls/TrainingUnitsSpinBox" % prefix)
	) as SpinBox
	var apply_button: Button = main_instance.get_node_or_null(
		NodePath("%s/ComputePlanControls/ApplyComputePlanButton" % prefix)
	) as Button
	var advance_button: Button = main_instance.get_node_or_null(
		NodePath("%s/ComputePlanControls/AdvanceQuarterButton" % prefix)
	) as Button
	var primary_button: Button = main_instance.get_node_or_null(
		NodePath("%s/PrimaryButton" % prefix)
	) as Button
	var title_label: Label = main_instance.get_node_or_null(
		NodePath("%s/Header/TitleLabel" % prefix)
	) as Label
	var date_label: Label = main_instance.get_node_or_null(
		NodePath("%s/Header/DateLabel" % prefix)
	) as Label
	var header_separator: HSeparator = main_instance.get_node_or_null(
		NodePath("%s/HeaderSeparator" % prefix)
	) as HSeparator
	var status_label: Label = main_instance.get_node_or_null(
		NodePath("%s/PrototypeReportBar/PrototypeStatusLabel" % prefix)
	) as Label
	var selected_label: Label = main_instance.get_node_or_null(
		NodePath("%s/PrototypeReportBar/SelectedReportLabel" % prefix)
	) as Label
	var previous_button: Button = main_instance.get_node_or_null(
		NodePath("%s/PrototypeReportBar/PreviousReportButton" % prefix)
	) as Button
	var next_button: Button = main_instance.get_node_or_null(
		NodePath("%s/PrototypeReportBar/NextReportButton" % prefix)
	) as Button
	var details_button: Button = main_instance.get_node_or_null(
		NodePath("%s/PrototypeReportBar/ReportDetailsButton" % prefix)
	) as Button
	var summary_label: Label = main_instance.get_node_or_null(
		NodePath("%s/ReportSummaryLabel" % prefix)
	) as Label
	var detail_scroll: ScrollContainer = main_instance.get_node_or_null(
		NodePath("%s/ReportDetailScroll" % prefix)
	) as ScrollContainer
	var detail_label: Label = main_instance.get_node_or_null(
		NodePath("%s/ReportDetailScroll/ReportDetailLabel" % prefix)
	) as Label
	var report_heading: Label = main_instance.get_node_or_null(
		NodePath("%s/PrototypeHeading" % prefix)
	) as Label
	var report_bar: HBoxContainer = main_instance.get_node_or_null(
		NodePath("%s/PrototypeReportBar" % prefix)
	) as HBoxContainer
	var body_spacer: Control = main_instance.get_node_or_null(
		NodePath("%s/BodySpacer" % prefix)
	) as Control
	var required_nodes: Array = [
		training_spin_box,
		apply_button,
		advance_button,
		primary_button,
		title_label,
		date_label,
		header_separator,
		status_label,
		selected_label,
		previous_button,
		next_button,
		details_button,
		summary_label,
		detail_scroll,
		detail_label,
		report_heading,
		report_bar,
		body_spacer,
	]
	for required_node in required_nodes:
		if required_node == null:
			return false
	if (
		status_label.text != "Prototype quarter: 1/6"
		or selected_label.text != "Quarter Report — Q1"
		or summary_label.text != _expected_ui_summary(1)
		or detail_scroll.visible
	):
		return false

	for quarter_number in range(2, 7):
		training_spin_box.value = 40.0
		apply_button.pressed.emit()
		await main_instance.get_tree().process_frame
		if (
			selected_label.text
				!= "Quarter Report — Q%d" % (quarter_number - 1)
			or status_label.text
				!= "Prototype quarter: %d/6" % (quarter_number - 1)
		):
			return false
		advance_button.pressed.emit()
		await main_instance.get_tree().process_frame
		if (
			selected_label.text != "Quarter Report — Q%d" % quarter_number
			or summary_label.text != _expected_ui_summary(quarter_number)
		):
			return false

	var completion_exact: bool = (
		status_label.text == "Prototype complete: 6/6"
		and selected_label.text == "Quarter Report — Q6"
		and not detail_scroll.visible
		and primary_button.text == "START PROJECT"
		and primary_button.is_visible_in_tree()
		and primary_button.disabled
		and apply_button.text == "SET COMPUTE ALLOCATION"
		and apply_button.is_visible_in_tree()
		and apply_button.disabled
		and advance_button.text == "ADVANCE QUARTER"
		and advance_button.is_visible_in_tree()
		and advance_button.disabled
		and training_spin_box.is_visible_in_tree()
		and not training_spin_box.editable
		and details_button.text == "DETAILS"
	)
	if not completion_exact:
		return false
	var committed_business_surface: Array = _dashboard_business_surface(
		main_instance
	)
	primary_button.pressed.emit()
	apply_button.pressed.emit()
	advance_button.pressed.emit()
	await main_instance.get_tree().process_frame
	if _dashboard_business_surface(main_instance) != committed_business_surface:
		return false

	for quarter_number in range(5, 0, -1):
		previous_button.pressed.emit()
		await main_instance.get_tree().process_frame
		if (
			selected_label.text != "Quarter Report — Q%d" % quarter_number
			or summary_label.text != _expected_ui_summary(quarter_number)
			or _dashboard_business_surface(main_instance)
				!= committed_business_surface
		):
			return false
	if not previous_button.disabled or next_button.disabled:
		return false

	details_button.pressed.emit()
	await main_instance.get_tree().process_frame
	if (
		not detail_scroll.visible
		or details_button.text != "HIDE DETAILS"
		or not detail_label.text.contains("Cash: 1,000,000 → 1,071,130 cents")
		or not detail_label.text.contains("Northstar Labs committed training-gap allocation")
		or _dashboard_business_surface(main_instance) != committed_business_surface
	):
		return false
	details_button.pressed.emit()
	await main_instance.get_tree().process_frame
	if detail_scroll.visible or details_button.text != "DETAILS":
		return false

	for quarter_number in range(2, 7):
		next_button.pressed.emit()
		await main_instance.get_tree().process_frame
		if (
			selected_label.text != "Quarter Report — Q%d" % quarter_number
			or summary_label.text != _expected_ui_summary(quarter_number)
			or _dashboard_business_surface(main_instance)
				!= committed_business_surface
		):
			return false
	if previous_button.disabled or not next_button.disabled:
		return false

	details_button.pressed.emit()
	await main_instance.get_tree().process_frame
	if (
		not detail_scroll.visible
		or details_button.text != "HIDE DETAILS"
		or not detail_label.text.contains("Cash: 1,577,590 → 1,606,330 cents")
		or not detail_label.text.contains(
			"Prototype complete — no next quarter."
		)
		or _dashboard_business_surface(main_instance) != committed_business_surface
	):
		return false

	var report_controls: Array[Control] = [
		title_label,
		date_label,
		header_separator,
		training_spin_box,
		apply_button,
		advance_button,
		primary_button,
		report_heading,
		report_bar,
		status_label,
		selected_label,
		previous_button,
		next_button,
		details_button,
		summary_label,
		detail_scroll,
		body_spacer,
	]
	for resolution in [
		Vector2i(1152, 648),
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
	]:
		viewport.size = resolution
		await main_instance.get_tree().process_frame
		await main_instance.get_tree().process_frame
		if not _report_layout_fits(main_instance, report_controls, resolution):
			return false
	return (
		selected_label.text == "Quarter Report — Q6"
		and detail_scroll.visible
		and details_button.text == "HIDE DETAILS"
		and status_label.text == "Prototype complete: 6/6"
	)


static func _test_six_quarter_golden_and_repeat() -> bool:
	var first: GameSessionType = GameSessionType.new(
		_create_canonical_state(),
		_create_canonical_personality()
	)
	if not _execute_canonical_schedule(first):
		return false
	if (
		_state_primitives(first.get_state_snapshot())
			!= _expected_terminal_state_primitives()
		or first.get_prototype_quarter_count() != 6
		or not first.is_prototype_complete()
		or first.has_cached_opponent_preview()
		or not _reports_match_goldens(first.get_quarter_reports())
	):
		return false

	var second: GameSessionType = GameSessionType.new(
		_create_canonical_state(),
		_create_canonical_personality()
	)
	return (
		_execute_canonical_schedule(second)
		and _session_primitives(first) == _session_primitives(second)
		and _reports_match_goldens(second.get_quarter_reports())
	)


static func _test_failed_and_completed_commands_are_atomic() -> bool:
	var overflow_session: GameSessionType = GameSessionType.new(
		_create_canonical_state(MAX_SIGNED_INT - 100_000),
		_create_canonical_personality()
	)
	var overflow_counter: SignalCounter = SignalCounter.new()
	overflow_session.committed_result.connect(overflow_counter.capture)
	if (
		not overflow_session.submit_command(StartProjectCommandType.new()).is_successful()
		or not overflow_session.submit_command(
			SetComputeAllocationCommandType.new(40)
		).is_successful()
		or not overflow_session.submit_command(
			AdvanceQuarterCommandType.new()
		).is_successful()
		or not overflow_session.submit_command(
			SetComputeAllocationCommandType.new(40)
		).is_successful()
	):
		return false
	var overflow_before: Array = _session_primitives(overflow_session)
	var overflow_view_model: DashboardViewModelType = (
		overflow_session.get_current_view_model()
	)
	var overflow_signals_before: int = overflow_counter.count
	var overflow_rejected: bool = not overflow_session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	if (
		not overflow_rejected
		or overflow_counter.count != overflow_signals_before
		or overflow_session.get_current_view_model() != overflow_view_model
		or _session_primitives(overflow_session) != overflow_before
		or overflow_session.get_quarter_reports().size() != 1
	):
		return false

	var completed_session: GameSessionType = GameSessionType.new(
		_create_canonical_state(),
		_create_canonical_personality()
	)
	var completed_counter: SignalCounter = SignalCounter.new()
	completed_session.committed_result.connect(completed_counter.capture)
	if not _execute_canonical_schedule(completed_session):
		return false
	var completed_before: Array = _session_primitives(completed_session)
	var completed_view_model: DashboardViewModelType = (
		completed_session.get_current_view_model()
	)
	var completed_signals_before: int = completed_counter.count
	var start_rejected: bool = not completed_session.submit_command(
		StartProjectCommandType.new()
	).is_successful()
	var set_rejected: bool = not completed_session.submit_command(
		SetComputeAllocationCommandType.new(40)
	).is_successful()
	var seventh_rejected: bool = not completed_session.submit_command(
		AdvanceQuarterCommandType.new()
	).is_successful()
	var inactive_session: GameSessionType = GameSessionType.new(
		_create_inactive_canonical_state()
	)
	var inactive_complete: bool = (
		_execute_canonical_schedule(inactive_session)
		and inactive_session.is_prototype_complete()
		and inactive_session.get_prototype_quarter_count() == 6
		and inactive_session.get_quarter_reports().size() == 6
		and not inactive_session.has_cached_opponent_preview()
		and inactive_session.get_current_view_model().get_rival_signal_text()
			== "Prototype complete — no next signal"
	)
	return (
		start_rejected
		and set_rejected
		and seventh_rejected
		and completed_counter.count == completed_signals_before
		and completed_session.get_current_view_model() == completed_view_model
		and _session_primitives(completed_session) == completed_before
		and completed_session.get_quarter_reports().size() == 6
		and not completed_session.has_cached_opponent_preview()
		and inactive_complete
	)


static func _test_publication_observer_and_history_copies() -> bool:
	var session: GameSessionType = GameSessionType.new(
		_create_canonical_state(),
		_create_canonical_personality()
	)
	var observer: PublicationObserver = PublicationObserver.new(session)
	session.committed_result.connect(observer.capture)
	observer.expect_commit(0, 0, false)
	if not session.submit_command(StartProjectCommandType.new()).is_successful():
		return false
	for quarter_number in range(1, 7):
		observer.expect_commit(quarter_number - 1, (quarter_number - 1) * 3, false)
		if not session.submit_command(
			SetComputeAllocationCommandType.new(40)
		).is_successful():
			return false
		observer.expect_commit(
			quarter_number,
			quarter_number * 3,
			quarter_number == 6
		)
		if not session.submit_command(AdvanceQuarterCommandType.new()).is_successful():
			return false
	var returned_reports: Array[QuarterReportType] = session.get_quarter_reports()
	var returned_view_models: Array = (
		session.get_current_view_model().get_quarter_report_view_models()
	)
	returned_reports.clear()
	returned_view_models.clear()
	return (
		observer.count == 13
		and observer.all_signals_saw_committed_values
		and observer.observed_report_counts
			== [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6]
		and session.get_quarter_reports().size() == 6
		and session.get_current_view_model().get_quarter_report_count() == 6
		and _reports_match_goldens(session.get_quarter_reports())
	)


static func _execute_canonical_schedule(session: GameSessionType) -> bool:
	if session == null:
		return false
	if not session.submit_command(StartProjectCommandType.new()).is_successful():
		return false
	for _quarter_number in range(1, 7):
		if not session.submit_command(
			SetComputeAllocationCommandType.new(40)
		).is_successful():
			return false
		if not session.submit_command(AdvanceQuarterCommandType.new()).is_successful():
			return false
	return true


static func _reports_match_goldens(reports: Array[QuarterReportType]) -> bool:
	if reports.size() != 6:
		return false
	var before_values: Array = [
		[1_000_000, 120_000, 3_000, 30_000, 2_000, 90_000, 0, 0, 0],
		[1_071_130, 146_130, 3_018, 30_180, 1_910, 85_950, 120, 150, 0],
		[1_256_470, 133_080, 2_928, 29_280, 1_640, 73_800, 240, 300, 0],
		[1_402_660, 120_030, 2_838, 28_380, 1_370, 61_650, 360, 450, 0],
		[1_509_700, 106_980, 2_748, 27_480, 1_100, 49_500, 480, 600, 0],
		[1_577_590, 93_930, 2_658, 26_580, 830, 37_350, 600, 750, 0],
	]
	var after_values: Array = [
		[1_071_130, 146_130, 3_018, 30_180, 1_910, 85_950, 120, 150, 0],
		[1_256_470, 133_080, 2_928, 29_280, 1_640, 73_800, 240, 300, 0],
		[1_402_660, 120_030, 2_838, 28_380, 1_370, 61_650, 360, 450, 0],
		[1_509_700, 106_980, 2_748, 27_480, 1_100, 49_500, 480, 600, 0],
		[1_577_590, 93_930, 2_658, 26_580, 830, 37_350, 600, 750, 0],
		[1_606_330, 80_880, 2_568, 25_680, 560, 25_200, 720, 900, 0],
	]
	var contribution_counts: Array[int] = [52, 42, 42, 42, 42, 42]
	var committed_metadata: Array = [
		[&"plan_70_close_training_gap", 70, &"close_training_gap", 680, 8, 688],
		[&"plan_40_defend_markets", 40, &"defend_market_position", 549, 4, 553],
		[&"plan_40_defend_markets", 40, &"defend_market_position", 545, 5, 550],
		[&"plan_40_defend_markets", 40, &"defend_market_position", 542, 6, 548],
		[&"plan_40_defend_markets", 40, &"defend_market_position", 538, 0, 538],
		[&"plan_40_defend_markets", 40, &"defend_market_position", 534, 7, 541],
	]
	var metric_keys: Array[StringName] = _metric_keys()
	for report_index in reports.size():
		var quarter_number: int = report_index + 1
		var quarter_report: QuarterReportType = reports[report_index]
		if (
			quarter_report == null
			or not quarter_report.is_valid()
			or quarter_report.get_quarter_number() != quarter_number
			or quarter_report.get_start_elapsed_months() != report_index * 3
			or quarter_report.get_end_elapsed_months() != quarter_number * 3
			or quarter_report.get_contributions().size()
				!= contribution_counts[report_index]
			or quarter_report.get_committed_opponent_id() != &"northstar_labs"
			or _metric_values_from_report(quarter_report, true)
				!= before_values[report_index]
			or _metric_values_from_report(quarter_report, false)
				!= after_values[report_index]
			or _committed_metadata(quarter_report)
				!= committed_metadata[report_index]
			or _displayed_reason_order(quarter_report, metric_keys)
				!= _expected_displayed_reason_order(quarter_number)
		):
			return false
		if quarter_number < 6:
			if (
				not quarter_report.has_next_signal()
				or quarter_report.get_next_candidate_key()
					!= &"plan_40_defend_markets"
				or quarter_report.get_next_training_units_per_month() != 40
				or quarter_report.get_next_reason_key()
					!= &"defend_market_position"
				or quarter_report.is_prototype_complete()
			):
				return false
		else:
			if (
				quarter_report.has_next_signal()
				or quarter_report.get_next_candidate_key() != &""
				or quarter_report.get_next_training_units_per_month() != 0
				or quarter_report.get_next_reason_key() != &""
				or not quarter_report.is_prototype_complete()
			):
				return false
	return true


static func _metric_keys() -> Array[StringName]:
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


static func _metric_values_from_report(
	report: QuarterReportType,
	use_before: bool
) -> Array:
	var values: Array = []
	for metric_key in _metric_keys():
		values.append(
			report.get_before_value(metric_key)
			if use_before
			else report.get_after_value(metric_key)
		)
	return values


static func _committed_metadata(report: QuarterReportType) -> Array:
	return [
		report.get_committed_candidate_key(),
		report.get_committed_training_units_per_month(),
		report.get_committed_reason_key(),
		report.get_committed_base_utility_points(),
		report.get_committed_noise_points(),
		report.get_committed_total_utility_points(),
	]


static func _displayed_reason_order(
	report: QuarterReportType,
	metric_keys: Array[StringName]
) -> Array:
	var by_metric: Array = []
	for metric_key in metric_keys:
		var reasons: Array[StringName] = []
		for contribution in report.get_displayed_contributions(metric_key):
			reasons.append(contribution.get_reason_key())
		by_metric.append(reasons)
	return by_metric


static func _expected_displayed_reason_order(quarter_number: int) -> Array:
	var cash: Array[StringName] = [
		EffectContributionType.REASON_MONTHLY_REVENUE,
		EffectContributionType.REASON_MONTHLY_REVENUE,
		EffectContributionType.REASON_MONTHLY_REVENUE,
	]
	var company_revenue: Array[StringName] = [
		EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
		EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
		EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
	]
	if quarter_number == 1:
		company_revenue = [
			EffectContributionType.REASON_PROJECT_COMPLETION_REVENUE,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
		]
	var consumer_share_reason: StringName = (
		EffectContributionType.REASON_MARKET_SHARE_CHANGE
		if quarter_number == 1
		else EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE
	)
	return [
		cash,
		company_revenue,
		[consumer_share_reason, consumer_share_reason, consumer_share_reason],
		[
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
		],
		[
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
			EffectContributionType.REASON_OPPONENT_MARKET_PRESSURE,
		],
		[
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
			EffectContributionType.REASON_MARKET_REVENUE_CHANGE,
		],
		[
			EffectContributionType.REASON_TRAINING_WORK,
			EffectContributionType.REASON_TRAINING_WORK,
			EffectContributionType.REASON_TRAINING_WORK,
		],
		[
			EffectContributionType.REASON_INFERENCE_SERVED,
			EffectContributionType.REASON_INFERENCE_SERVED,
			EffectContributionType.REASON_INFERENCE_SERVED,
		],
		[],
	]


## Duplicates the public canonical fixture; it does not depend on another suite.
static func _create_canonical_state(
	cash_cents: int = 1_000_000
) -> GameStateType:
	var company: CompanyStateType = CompanyStateType.new(
		cash_cents,
		120_000,
		80_000
	)
	var project: ProjectStateType = ProjectStateType.new(
		&"project_alpha",
		3,
		25_000,
		30_000
	)
	var compute: ComputeStateType = ComputeStateType.new(100, 10, 50, 40)
	var market: MarketStateType = MarketStateType.new(
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
	)
	var opponent_compute: ComputeStateType = ComputeStateType.new(
		100,
		10,
		50,
		40
	)
	var opponent: OpponentStateType = OpponentStateType.new(
		&"northstar_labs",
		opponent_compute
	)
	var named_rng: NamedRngStateType = (
		NamedRngStateType.create_fresh_version_one(7)
	)
	return GameStateType.new(
		company,
		project,
		compute,
		market,
		opponent,
		named_rng
	)


## Duplicates the public canonical personality and preserves candidate order.
static func _create_canonical_personality() -> OpponentPersonalityType:
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
		&"northstar_labs",
		"Northstar Labs",
		candidates,
		500,
		100,
		500,
		180
	)


static func _create_inactive_canonical_state() -> GameStateType:
	return GameStateType.new(
		CompanyStateType.new(1_000_000, 120_000, 80_000),
		ProjectStateType.new(&"project_alpha", 3, 25_000, 30_000),
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
			0,
			0
		),
		OpponentStateType.new(),
		NamedRngStateType.new()
	)


static func _expected_terminal_state_primitives() -> Array:
	return [
		18,
		[1_606_330, 80_880, 80_000],
		[&"project_alpha", 3, 25_000, 30_000, ProjectStateType.Lifecycle.COMPLETED, 3],
		[100, 10, 50, 40, 720, 900, 0],
		[
			30,
			20,
			6_000,
			2_568,
			560,
			100_000,
			450_000,
			30,
			10,
			10,
			25,
			30,
			20,
			25_680,
			25_200,
			540,
			0,
			360,
			0,
			2,
			5,
		],
		[
			&"northstar_labs",
			[100, 10, 50, 40, 810, 810, 90],
			&"plan_40_defend_markets",
			40,
			&"defend_market_position",
			534,
			7,
			541,
		],
		[7, 1, 1_981_546_508, 11, 13],
	]


static func _state_primitives(state: GameStateType) -> Array:
	if state == null:
		return []
	var company = state.get_company()
	var project = state.get_project()
	var compute = state.get_compute()
	var market = state.get_market()
	var opponent = state.get_opponent()
	var opponent_compute = opponent.get_compute()
	var named_rng = state.get_named_rng()
	return [
		state.get_clock().get_elapsed_months(),
		[
			company.get_cash_cents(),
			company.get_monthly_revenue_cents(),
			company.get_monthly_operating_cost_cents(),
		],
		[
			project.get_project_id(),
			project.get_required_months(),
			project.get_monthly_cost_cents(),
			project.get_completion_monthly_revenue_delta_cents(),
			project.get_lifecycle(),
			project.get_progress_months(),
		],
		_compute_primitives(compute),
		[
			market.get_consumer_workload_units_per_month(),
			market.get_developer_api_workload_units_per_month(),
			market.get_consumer_service_allocation_bps(),
			market.get_consumer_player_share_bps(),
			market.get_developer_api_player_share_bps(),
			market.get_consumer_addressable_monthly_revenue_cents(),
			market.get_developer_api_addressable_monthly_revenue_cents(),
			market.get_consumer_full_service_growth_bps(),
			market.get_developer_api_full_service_growth_bps(),
			market.get_consumer_unmet_penalty_bps_per_unit(),
			market.get_developer_api_unmet_penalty_bps_per_unit(),
			market.get_consumer_current_served_units_per_month(),
			market.get_developer_api_current_served_units_per_month(),
			market.get_consumer_current_market_revenue_cents(),
			market.get_developer_api_current_market_revenue_cents(),
			market.get_consumer_cumulative_served_compute_unit_months(),
			market.get_consumer_cumulative_unmet_compute_unit_months(),
			market.get_developer_api_cumulative_served_compute_unit_months(),
			market.get_developer_api_cumulative_unmet_compute_unit_months(),
			market.get_consumer_opponent_pressure_bps_per_served_unit(),
			market.get_developer_api_opponent_pressure_bps_per_served_unit(),
		],
		[
			opponent.get_opponent_id(),
			_compute_primitives(opponent_compute),
			opponent.get_last_candidate_key(),
			opponent.get_last_training_units_per_month(),
			opponent.get_last_reason_key(),
			opponent.get_last_base_utility_points(),
			opponent.get_last_noise_points(),
			opponent.get_last_total_utility_points(),
		],
		[
			named_rng.get_master_seed(),
			named_rng.get_algorithm_version(),
			named_rng.get_ai_stream_state(),
			named_rng.get_events_stream_state(),
			named_rng.get_market_stream_state(),
		],
	]


static func _compute_primitives(compute) -> Array:
	return [
		compute.get_total_units_per_month(),
		compute.get_reserve_units_per_month(),
		compute.get_inference_workload_units_per_month(),
		compute.get_training_allocation_units_per_month(),
		compute.get_cumulative_training_compute_unit_months(),
		compute.get_cumulative_served_inference_compute_unit_months(),
		compute.get_cumulative_unmet_inference_compute_unit_months(),
	]


static func _session_primitives(session: GameSessionType) -> Array:
	var planning_snapshot = session.get_cached_opponent_planning_snapshot()
	return [
		_state_primitives(session.get_state_snapshot()),
		_serialize_reports(session.get_quarter_reports()),
		_serialize_contributions(session.get_last_committed_contributions()),
		_serialize_contributions(session.get_last_rival_contributions()),
		[
			planning_snapshot.get_elapsed_months(),
			planning_snapshot.get_consumer_player_share_bps(),
			planning_snapshot.get_developer_api_player_share_bps(),
		],
		session.has_cached_opponent_preview(),
		session.get_prototype_quarter_count(),
		session.is_prototype_complete(),
		_view_model_primitives(session.get_current_view_model()),
	]


static func _serialize_reports(reports: Array[QuarterReportType]) -> Array:
	var serialized: Array = []
	for report in reports:
		var displayed: Array = []
		for metric_key in _metric_keys():
			displayed.append(_serialize_contributions(
				report.get_displayed_contributions(metric_key)
			))
		serialized.append([
			report.get_quarter_number(),
			report.get_start_elapsed_months(),
			report.get_end_elapsed_months(),
			_metric_values_from_report(report, true),
			_metric_values_from_report(report, false),
			displayed,
			_serialize_contributions(report.get_contributions()),
			report.get_committed_opponent_id(),
			_committed_metadata(report),
			report.has_next_signal(),
			report.get_next_candidate_key(),
			report.get_next_training_units_per_month(),
			report.get_next_reason_key(),
			report.is_prototype_complete(),
		])
	return serialized


static func _serialize_contributions(contributions: Array) -> Array:
	var serialized: Array = []
	for contribution in contributions:
		serialized.append([
			contribution.get_source_key(),
			contribution.get_reason_key(),
			contribution.get_subject_key(),
			contribution.get_metric_key(),
			contribution.get_unit(),
			contribution.get_delta(),
		])
	return serialized


static func _view_model_primitives(view_model: DashboardViewModelType) -> Array:
	if view_model == null:
		return []
	var report_view_models: Array = []
	for report_view_model in view_model.get_quarter_report_view_models():
		report_view_models.append([
			report_view_model.is_valid(),
			report_view_model.get_quarter_number(),
			report_view_model.get_report_title_text(),
			report_view_model.get_summary_text(),
			report_view_model.get_detail_text(),
			report_view_model.get_rival_action_text(),
			report_view_model.get_opportunity_cost_text(),
			report_view_model.get_known_risk_text(),
		])
	return [
		view_model.get_title_text(),
		view_model.get_date_text(),
		view_model.get_cash_text(),
		view_model.get_monthly_revenue_text(),
		view_model.get_monthly_operating_cost_text(),
		view_model.get_project_text(),
		view_model.get_action_text(),
		view_model.is_start_project_available(),
		view_model.get_cash_explanation_text(),
		view_model.get_revenue_contributions_text(),
		view_model.get_operating_cost_contributions_text(),
		view_model.get_project_cost_contributions_text(),
		view_model.get_progress_contributions_text(),
		view_model.get_completion_revenue_text(),
		view_model.get_compute_plan_text(),
		view_model.get_inference_workload_text(),
		view_model.get_training_allocation_units_per_month(),
		view_model.get_maximum_training_allocation_units_per_month(),
		view_model.get_training_work_text(),
		view_model.get_inference_served_text(),
		view_model.get_inference_unmet_text(),
		view_model.get_consumer_market_text(),
		view_model.get_developer_api_market_text(),
		view_model.get_rival_signal_text(),
		view_model.get_rival_reason_text(),
		view_model.get_rival_utility_text(),
		view_model.get_rival_last_action_text(),
		view_model.get_rival_quarter_text(),
		view_model.get_rival_market_pressure_text(),
		view_model.get_prototype_status_text(),
		view_model.get_prototype_quarter_count(),
		view_model.is_prototype_complete(),
		view_model.are_business_actions_enabled(),
		report_view_models,
	]


static func _dashboard_business_surface(main_instance: Control) -> Array:
	var paths: Array[NodePath] = [
		^"DashboardMargin/Dashboard/Header/DateLabel",
		^"DashboardMargin/Dashboard/FinanceGrid/CashLabel",
		^"DashboardMargin/Dashboard/FinanceGrid/RevenueLabel",
		^"DashboardMargin/Dashboard/FinanceGrid/OperatingCostLabel",
		^"DashboardMargin/Dashboard/ProjectLabel",
		^"DashboardMargin/Dashboard/ComputePlanLabel",
		^"DashboardMargin/Dashboard/InferenceWorkloadLabel",
		^"DashboardMargin/Dashboard/MarketsGrid/ConsumerMarketLabel",
		^"DashboardMargin/Dashboard/MarketsGrid/DeveloperApiMarketLabel",
		^"DashboardMargin/Dashboard/RivalGrid/RivalSignalLabel",
		^"DashboardMargin/Dashboard/RivalGrid/RivalLastActionLabel",
		^"DashboardMargin/Dashboard/RivalGrid/RivalReasonLabel",
		^"DashboardMargin/Dashboard/RivalGrid/RivalQuarterLabel",
		^"DashboardMargin/Dashboard/RivalGrid/RivalUtilityLabel",
		^"DashboardMargin/Dashboard/RivalGrid/RivalMarketPressureLabel",
		^"DashboardMargin/Dashboard/Explanation/CashReconciliationLabel",
		^"DashboardMargin/Dashboard/Explanation/RevenueContributionLabel",
		^"DashboardMargin/Dashboard/Explanation/OperatingCostContributionLabel",
		^"DashboardMargin/Dashboard/Explanation/ProjectCostContributionLabel",
		^"DashboardMargin/Dashboard/Explanation/ProgressContributionLabel",
		^"DashboardMargin/Dashboard/Explanation/CompletionRevenueContributionLabel",
		^"DashboardMargin/Dashboard/Explanation/ComputeExplanationGrid/TrainingWorkLabel",
		^"DashboardMargin/Dashboard/Explanation/ComputeExplanationGrid/InferenceServedLabel",
		^"DashboardMargin/Dashboard/Explanation/ComputeExplanationGrid/InferenceUnmetLabel",
		^"DashboardMargin/Dashboard/PrototypeReportBar/PrototypeStatusLabel",
	]
	var surface: Array = []
	for path in paths:
		var label: Label = main_instance.get_node_or_null(path) as Label
		if label == null:
			return []
		surface.append(label.text)
	var primary_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrimaryButton"
	) as Button
	var apply_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/ApplyComputePlanButton"
	) as Button
	var advance_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/AdvanceQuarterButton"
	) as Button
	var spin_box: SpinBox = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/TrainingUnitsSpinBox"
	) as SpinBox
	if (
		primary_button == null
		or apply_button == null
		or advance_button == null
		or spin_box == null
	):
		return []
	surface.append_array([
		primary_button.text,
		primary_button.disabled,
		primary_button.is_visible_in_tree(),
		apply_button.text,
		apply_button.disabled,
		apply_button.is_visible_in_tree(),
		advance_button.text,
		advance_button.disabled,
		advance_button.is_visible_in_tree(),
		spin_box.editable,
		spin_box.is_visible_in_tree(),
		int(spin_box.value),
		int(spin_box.max_value),
	])
	return surface


static func _expected_ui_summary(quarter_number: int) -> String:
	var summaries: Array[String] = [
		(
			"Cash 1,000,000 → 1,071,130 cents  |  Revenue 120,000 → 146,130 cents/month\n"
			+ "Consumer 3,000 → 3,018 bps; revenue 30,000 → 30,180 cents/month  |  Developer/API 2,000 → 1,910 bps; revenue 90,000 → 85,950 cents/month\n"
			+ "Training 0 → 120 compute-unit-months  |  Inference served 0 → 150; unmet 0 → 0 compute-unit-months"
		),
		(
			"Cash 1,071,130 → 1,256,470 cents  |  Revenue 146,130 → 133,080 cents/month\n"
			+ "Consumer 3,018 → 2,928 bps; revenue 30,180 → 29,280 cents/month  |  Developer/API 1,910 → 1,640 bps; revenue 85,950 → 73,800 cents/month\n"
			+ "Training 120 → 240 compute-unit-months  |  Inference served 150 → 300; unmet 0 → 0 compute-unit-months"
		),
		(
			"Cash 1,256,470 → 1,402,660 cents  |  Revenue 133,080 → 120,030 cents/month\n"
			+ "Consumer 2,928 → 2,838 bps; revenue 29,280 → 28,380 cents/month  |  Developer/API 1,640 → 1,370 bps; revenue 73,800 → 61,650 cents/month\n"
			+ "Training 240 → 360 compute-unit-months  |  Inference served 300 → 450; unmet 0 → 0 compute-unit-months"
		),
		(
			"Cash 1,402,660 → 1,509,700 cents  |  Revenue 120,030 → 106,980 cents/month\n"
			+ "Consumer 2,838 → 2,748 bps; revenue 28,380 → 27,480 cents/month  |  Developer/API 1,370 → 1,100 bps; revenue 61,650 → 49,500 cents/month\n"
			+ "Training 360 → 480 compute-unit-months  |  Inference served 450 → 600; unmet 0 → 0 compute-unit-months"
		),
		(
			"Cash 1,509,700 → 1,577,590 cents  |  Revenue 106,980 → 93,930 cents/month\n"
			+ "Consumer 2,748 → 2,658 bps; revenue 27,480 → 26,580 cents/month  |  Developer/API 1,100 → 830 bps; revenue 49,500 → 37,350 cents/month\n"
			+ "Training 480 → 600 compute-unit-months  |  Inference served 600 → 750; unmet 0 → 0 compute-unit-months"
		),
		(
			"Cash 1,577,590 → 1,606,330 cents  |  Revenue 93,930 → 80,880 cents/month\n"
			+ "Consumer 2,658 → 2,568 bps; revenue 26,580 → 25,680 cents/month  |  Developer/API 830 → 560 bps; revenue 37,350 → 25,200 cents/month\n"
			+ "Training 600 → 720 compute-unit-months  |  Inference served 750 → 900; unmet 0 → 0 compute-unit-months"
		),
	]
	if quarter_number < 1 or quarter_number > summaries.size():
		return ""
	return summaries[quarter_number - 1]


static func _report_layout_fits(
	main_instance: Control,
	report_controls: Array[Control],
	resolution: Vector2i
) -> bool:
	var viewport: Viewport = main_instance.get_viewport()
	if viewport == null or not viewport is Window:
		return false
	var window: Window = viewport as Window
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	if (
		window.size != resolution
		or window.content_scale_size != Vector2i(1152, 648)
		or viewport_rect.size != Vector2(1152, 648)
		or not main_instance.is_visible_in_tree()
		or main_instance.get_global_rect().size
			!= viewport_rect.size
		or not viewport_rect.encloses(main_instance.get_global_rect())
	):
		return false
	for control in report_controls:
		if (
			control == null
			or not control.is_visible_in_tree()
			or not viewport_rect.encloses(control.get_global_rect())
		):
			return false
	var dashboard: VBoxContainer = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard"
	) as VBoxContainer
	var header: HBoxContainer = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Header"
	) as HBoxContainer
	var title_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Header/TitleLabel"
	) as Label
	var date_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Header/DateLabel"
	) as Label
	var header_separator: HSeparator = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/HeaderSeparator"
	) as HSeparator
	var detail_scroll: ScrollContainer = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ReportDetailScroll"
	) as ScrollContainer
	var detail_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ReportDetailScroll/ReportDetailLabel"
	) as Label
	var body_spacer: Control = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/BodySpacer"
	) as Control
	if (
		dashboard == null
		or header == null
		or title_label == null
		or date_label == null
		or header_separator == null
		or detail_scroll == null
		or detail_label == null
		or body_spacer == null
	):
		return false
	var main_rect: Rect2 = main_instance.get_global_rect()
	var dashboard_rect: Rect2 = dashboard.get_global_rect()
	var top_safe_gap: float = dashboard_rect.position.y - main_rect.position.y
	var bottom_safe_gap: float = (
		main_rect.position.y + main_rect.size.y
		- dashboard_rect.position.y - dashboard_rect.size.y
	)
	var header_rect: Rect2 = header.get_global_rect()
	var title_font: Font = title_label.get_theme_font(&"font")
	var date_font: Font = date_label.get_theme_font(&"font")
	var required_header_height: float = maxf(
		title_font.get_height(title_label.get_theme_font_size(&"font_size")),
		date_font.get_height(date_label.get_theme_font_size(&"font_size"))
	) + 8.0
	var detail_rect: Rect2 = detail_scroll.get_global_rect()
	var body_spacer_rect: Rect2 = body_spacer.get_global_rect()
	if (
		top_safe_gap < 8.0
		or bottom_safe_gap < 8.0
		or not header_rect.encloses(title_label.get_global_rect())
		or not header_rect.encloses(date_label.get_global_rect())
		or header_rect.size.y < required_header_height
		or header_separator.get_global_rect().position.y
			< header_rect.position.y + header_rect.size.y
		or not detail_scroll.clip_contents
		or body_spacer_rect.size.y < 8.0
		or body_spacer_rect.position.y < detail_rect.position.y + detail_rect.size.y
		or detail_rect.position.y + detail_rect.size.y + 8.0
			> dashboard_rect.position.y + dashboard_rect.size.y
	):
		return false
	if detail_label.get_combined_minimum_size().y > detail_rect.size.y:
		var vertical_scroll_bar: VScrollBar = detail_scroll.get_v_scroll_bar()
		if (
			vertical_scroll_bar == null
			or not vertical_scroll_bar.is_visible_in_tree()
			or vertical_scroll_bar.max_value <= vertical_scroll_bar.page
		):
			return false
	return (
		detail_scroll.is_visible_in_tree()
		and detail_scroll.size.y >= 60.0
		and detail_scroll.size.y < viewport_rect.size.y
	)


static func _report(report: Callable, condition: bool, message: String) -> void:
	report.call(condition, message)
