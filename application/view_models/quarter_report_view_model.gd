class_name QuarterReportViewModel
extends RefCounted


const QuarterReportType = preload("res://simulation/reports/quarter_report.gd")

const _METRIC_KEYS: Array[StringName] = [
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
const _METRIC_DISPLAY_NAMES: Array[String] = [
	"Cash",
	"Company monthly revenue",
	"Consumer share",
	"Consumer monthly revenue",
	"Developer/API share",
	"Developer/API monthly revenue",
	"Training work",
	"Served inference",
	"Unmet inference",
]
const _METRIC_UNITS: Array[String] = [
	"cents",
	"cents/month",
	"bps",
	"cents/month",
	"bps",
	"cents/month",
	"compute-unit-months",
	"compute-unit-months",
	"compute-unit-months",
]

var _is_valid: bool = false
var _quarter_number: int = 0
var _report_title_text: String = ""
var _summary_lines: Array[String] = []
var _detail_lines: Array[String] = []
var _rival_action_text: String = ""
var _opportunity_cost_text: String = ""
var _known_risk_text: String = ""


## Maps one immutable committed report into copied player-facing primitives only.
func _init(p_report: QuarterReportType, opponent_display_name: String) -> void:
	if p_report == null or not p_report.is_valid():
		return
	var quarter_number: int = p_report.get_quarter_number()
	if quarter_number < 1 or quarter_number > 6:
		return

	var metric_before_values: Array[int] = []
	var metric_after_values: Array[int] = []
	var metric_reason_lines: Array[String] = []
	for metric_index in _METRIC_KEYS.size():
		var metric_key: StringName = _METRIC_KEYS[metric_index]
		var before_value: int = p_report.get_before_value(metric_key)
		var after_value: int = p_report.get_after_value(metric_key)
		metric_before_values.append(before_value)
		metric_after_values.append(after_value)
		metric_reason_lines.append(_format_reasons(
			p_report.get_displayed_contributions(metric_key),
			metric_key
		))

	_quarter_number = quarter_number
	_report_title_text = "Quarter Report — Q%d" % quarter_number
	_summary_lines = _build_summary_lines(metric_before_values, metric_after_values)
	_rival_action_text = _build_rival_action_text(p_report, opponent_display_name)
	_opportunity_cost_text = _build_opportunity_cost_text(
		metric_before_values,
		metric_after_values
	)
	_known_risk_text = _build_known_risk_text(
		p_report,
		opponent_display_name,
		metric_after_values[8]
	)
	_detail_lines = _build_detail_lines(
		metric_before_values,
		metric_after_values,
		metric_reason_lines
	)
	_detail_lines.append("")
	_detail_lines.append(_rival_action_text)
	_detail_lines.append(_opportunity_cost_text)
	_detail_lines.append(_known_risk_text)
	_is_valid = true


func is_valid() -> bool:
	return _is_valid


func get_quarter_number() -> int:
	return _quarter_number


func get_report_title_text() -> String:
	return _report_title_text


func get_summary_text() -> String:
	if _summary_lines.size() != 6:
		return ""
	return "%s  |  %s\n%s  |  %s\n%s  |  %s" % [
		_summary_lines[0],
		_summary_lines[1],
		_summary_lines[2],
		_summary_lines[3],
		_summary_lines[4],
		_summary_lines[5],
	]


func get_detail_text() -> String:
	return "\n".join(_detail_lines)


func get_rival_action_text() -> String:
	return _rival_action_text


func get_opportunity_cost_text() -> String:
	return _opportunity_cost_text


func get_known_risk_text() -> String:
	return _known_risk_text


func _build_summary_lines(before_values: Array[int], after_values: Array[int]) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Cash %s → %s cents" % [
		_format_integer(before_values[0]),
		_format_integer(after_values[0]),
	])
	lines.append("Revenue %s → %s cents/month" % [
		_format_integer(before_values[1]),
		_format_integer(after_values[1]),
	])
	lines.append("Consumer %s → %s bps; revenue %s → %s cents/month" % [
		_format_integer(before_values[2]),
		_format_integer(after_values[2]),
		_format_integer(before_values[3]),
		_format_integer(after_values[3]),
	])
	lines.append("Developer/API %s → %s bps; revenue %s → %s cents/month" % [
		_format_integer(before_values[4]),
		_format_integer(after_values[4]),
		_format_integer(before_values[5]),
		_format_integer(after_values[5]),
	])
	lines.append("Training %s → %s compute-unit-months" % [
		_format_integer(before_values[6]),
		_format_integer(after_values[6]),
	])
	lines.append("Inference served %s → %s; unmet %s → %s compute-unit-months" % [
		_format_integer(before_values[7]),
		_format_integer(after_values[7]),
		_format_integer(before_values[8]),
		_format_integer(after_values[8]),
	])
	return lines


func _build_detail_lines(
	before_values: Array[int],
	after_values: Array[int],
	reason_lines: Array[String]
) -> Array[String]:
	var lines: Array[String] = []
	for metric_index in _METRIC_KEYS.size():
		lines.append("%s: %s → %s %s" % [
			_METRIC_DISPLAY_NAMES[metric_index],
			_format_integer(before_values[metric_index]),
			_format_integer(after_values[metric_index]),
			_METRIC_UNITS[metric_index],
		])
		lines.append("  Reasons: %s" % reason_lines[metric_index])
	return lines


func _build_rival_action_text(
	report: QuarterReportType,
	opponent_display_name: String
) -> String:
	if report.get_committed_opponent_id() == &"":
		return "No committed rival action."
	var rival_name: String = opponent_display_name.strip_edges()
	if rival_name.is_empty():
		rival_name = "Rival"
	var action_display: String = _candidate_display_text(
		report.get_committed_candidate_key()
	)
	var reason_display: String = _reason_display_text(report.get_committed_reason_key())
	return "%s committed %s: %s training units/month — %s. Seeded noise %s; utility %s = %s + %s." % [
		rival_name,
		action_display,
		_format_integer(report.get_committed_training_units_per_month()),
		reason_display,
		_format_signed_integer(report.get_committed_noise_points()),
		_format_integer(report.get_committed_total_utility_points()),
		_format_integer(report.get_committed_base_utility_points()),
		_format_integer(report.get_committed_noise_points()),
	]


func _build_opportunity_cost_text(
	before_values: Array[int],
	after_values: Array[int]
) -> String:
	return "Observed compute opportunity cost: training %s; served inference %s; unmet inference %s compute-unit-months." % [
		_format_signed_integer(after_values[6] - before_values[6]),
		_format_signed_integer(after_values[7] - before_values[7]),
		_format_signed_integer(after_values[8] - before_values[8]),
	]


func _build_known_risk_text(
	report: QuarterReportType,
	opponent_display_name: String,
	current_unmet_inference: int
) -> String:
	if report.is_prototype_complete():
		return "Prototype complete — no next quarter."
	var rival_name: String = opponent_display_name.strip_edges()
	if rival_name.is_empty():
		rival_name = "Rival"
	if not report.has_next_signal():
		return "Known next-quarter risk: no public rival signal."
	return "Known next-quarter risk: unmet inference is %s compute-unit-months; %s signals %s with %s training units/month — %s." % [
		_format_integer(current_unmet_inference),
		rival_name,
		_candidate_display_text(report.get_next_candidate_key()),
		_format_integer(report.get_next_training_units_per_month()),
		_reason_display_text(report.get_next_reason_key()),
	]


func _format_reasons(contributions: Array, metric_key: StringName) -> String:
	var reason_texts: Array[String] = []
	for contribution in contributions:
		if contribution == null:
			continue
		var display_text: String = _reason_display_text(contribution.get_reason_key())
		if display_text == "Committed effect":
			display_text = _source_display_text(contribution.get_source_key())
		reason_texts.append("%s %s %s" % [
			display_text,
			_format_signed_integer(contribution.get_delta()),
			_metric_unit(metric_key),
		])
	if reason_texts.is_empty():
		return "No committed change"
	return "; ".join(reason_texts)


func _candidate_display_text(candidate_key: StringName) -> String:
	match candidate_key:
		&"plan_40_defend_markets":
			return "defend-markets allocation"
		&"plan_70_close_training_gap":
			return "training-gap allocation"
	return "rival allocation"


func _reason_display_text(reason_key: StringName) -> String:
	match reason_key:
		&"monthly_revenue":
			return "Monthly revenue"
		&"monthly_operating_cost":
			return "Operating cost"
		&"project_monthly_cost":
			return "Project cost"
		&"project_completion_revenue":
			return "Project completion revenue"
		&"market_share_change":
			return "Service and market response"
		&"opponent_market_pressure":
			return "Rival market pressure"
		&"market_revenue_change":
			return "Market revenue change"
		&"training_work":
			return "Training work"
		&"inference_served":
			return "Served inference"
		&"inference_unmet":
			return "Unmet inference"
		&"defend_market_position":
			return "Defend market position"
		&"close_training_gap":
			return "Close training gap"
	return "Committed effect"


func _source_display_text(source_key: StringName) -> String:
	match source_key:
		&"finance":
			return "Finance"
		&"project":
			return "Project"
		&"compute":
			return "Compute"
		&"market":
			return "Market"
	return "Committed effect"


func _metric_unit(metric_key: StringName) -> String:
	for metric_index in _METRIC_KEYS.size():
		if _METRIC_KEYS[metric_index] == metric_key:
			return _METRIC_UNITS[metric_index]
	return "units"


func _format_signed_integer(value: int) -> String:
	if value > 0:
		return "+%s" % _format_integer(value)
	return _format_integer(value)


func _format_integer(value: int) -> String:
	var digits: String = str(value)
	var is_negative: bool = digits.begins_with("-")
	if is_negative:
		digits = digits.substr(1)
	var formatted: String = ""
	while digits.length() > 3:
		var split_index: int = digits.length() - 3
		formatted = ",%s%s" % [digits.substr(split_index), formatted]
		digits = digits.substr(0, split_index)
	formatted = "%s%s" % [digits, formatted]
	return "-%s" % formatted if is_negative else formatted
