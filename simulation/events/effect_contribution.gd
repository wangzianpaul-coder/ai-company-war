class_name EffectContribution
extends RefCounted


## Unit carried by one signed contribution delta.
enum Unit {
	CENTS,
	MONTHS,
}

const SOURCE_FINANCE: StringName = &"finance"
const SOURCE_PROJECT: StringName = &"project"

const REASON_MONTHLY_REVENUE: StringName = &"monthly_revenue"
const REASON_MONTHLY_OPERATING_COST: StringName = &"monthly_operating_cost"
const REASON_PROJECT_MONTHLY_COST: StringName = &"project_monthly_cost"
const REASON_PROJECT_PROGRESS: StringName = &"project_progress"
const REASON_PROJECT_COMPLETION_REVENUE: StringName = &"project_completion_revenue"

const SUBJECT_COMPANY: StringName = &"company"

const METRIC_CASH_CENTS: StringName = &"cash_cents"
const METRIC_PROJECT_PROGRESS_MONTHS: StringName = &"project_progress_months"
const METRIC_MONTHLY_REVENUE_CENTS: StringName = &"monthly_revenue_cents"

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
