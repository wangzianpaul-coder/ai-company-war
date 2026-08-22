class_name EffectContribution
extends RefCounted


## Unit carried by one signed contribution delta.
enum Unit {
	CENTS,
	MONTHS,
	COMPUTE_UNIT_MONTHS,
	BASIS_POINTS,
}

const SOURCE_FINANCE: StringName = &"finance"
const SOURCE_PROJECT: StringName = &"project"
const SOURCE_COMPUTE: StringName = &"compute"
const SOURCE_MARKET: StringName = &"market"

const REASON_MONTHLY_REVENUE: StringName = &"monthly_revenue"
const REASON_MONTHLY_OPERATING_COST: StringName = &"monthly_operating_cost"
const REASON_PROJECT_MONTHLY_COST: StringName = &"project_monthly_cost"
const REASON_PROJECT_PROGRESS: StringName = &"project_progress"
const REASON_PROJECT_COMPLETION_REVENUE: StringName = &"project_completion_revenue"
const REASON_TRAINING_WORK: StringName = &"training_work"
const REASON_INFERENCE_SERVED: StringName = &"inference_served"
const REASON_INFERENCE_UNMET: StringName = &"inference_unmet"
const REASON_MARKET_SERVED: StringName = &"market_served"
const REASON_MARKET_UNMET: StringName = &"market_unmet"
const REASON_MARKET_SHARE_CHANGE: StringName = &"market_share_change"
const REASON_MARKET_REVENUE_CHANGE: StringName = &"market_revenue_change"

const SUBJECT_COMPANY: StringName = &"company"
const SUBJECT_CONSUMER: StringName = &"consumer"
const SUBJECT_DEVELOPER_API: StringName = &"developer_api"

const METRIC_CASH_CENTS: StringName = &"cash_cents"
const METRIC_PROJECT_PROGRESS_MONTHS: StringName = &"project_progress_months"
const METRIC_MONTHLY_REVENUE_CENTS: StringName = &"monthly_revenue_cents"
const METRIC_CUMULATIVE_TRAINING_COMPUTE_UNIT_MONTHS: StringName = (
	&"cumulative_training_compute_unit_months"
)
const METRIC_CUMULATIVE_SERVED_INFERENCE_COMPUTE_UNIT_MONTHS: StringName = (
	&"cumulative_served_inference_compute_unit_months"
)
const METRIC_CUMULATIVE_UNMET_INFERENCE_COMPUTE_UNIT_MONTHS: StringName = (
	&"cumulative_unmet_inference_compute_unit_months"
)
const METRIC_CUMULATIVE_MARKET_SERVED_COMPUTE_UNIT_MONTHS: StringName = (
	&"cumulative_market_served_compute_unit_months"
)
const METRIC_CUMULATIVE_MARKET_UNMET_COMPUTE_UNIT_MONTHS: StringName = (
	&"cumulative_market_unmet_compute_unit_months"
)
const METRIC_PLAYER_SHARE_BPS: StringName = &"player_share_bps"
const METRIC_MARKET_MONTHLY_REVENUE_CENTS: StringName = &"market_monthly_revenue_cents"

var _source_key: StringName
var _reason_key: StringName
var _subject_key: StringName
var _metric_key: StringName
var _unit: Unit
var _delta: int


## Creates one immutable-by-interface explanation record with an explicit unit.
func _init(
	p_source_key: StringName,
	p_reason_key: StringName,
	p_subject_key: StringName,
	p_metric_key: StringName,
	p_unit: Unit,
	p_delta: int
) -> void:
	_source_key = p_source_key
	_reason_key = p_reason_key
	_subject_key = p_subject_key
	_metric_key = p_metric_key
	_unit = p_unit
	_delta = p_delta


func get_source_key() -> StringName:
	return _source_key


func get_reason_key() -> StringName:
	return _reason_key


func get_subject_key() -> StringName:
	return _subject_key


func get_metric_key() -> StringName:
	return _metric_key


func get_unit() -> Unit:
	return _unit


func get_delta() -> int:
	return _delta
