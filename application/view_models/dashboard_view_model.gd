class_name DashboardViewModel
extends RefCounted


var _title_text: String
var _date_text: String
var _cash_text: String
var _monthly_revenue_text: String
var _monthly_operating_cost_text: String
var _project_text: String
var _action_text: String
var _start_project_available: bool
var _cash_explanation_text: String
var _revenue_contributions_text: String
var _operating_cost_contributions_text: String
var _project_cost_contributions_text: String
var _progress_contributions_text: String
var _completion_revenue_text: String


## Stores primitive display values without exposing mutation methods.
func _init(
	p_title_text: String,
	p_date_text: String,
	p_cash_text: String,
	p_monthly_revenue_text: String,
	p_monthly_operating_cost_text: String,
	p_project_text: String,
	p_action_text: String,
	p_start_project_available: bool,
	p_cash_explanation_text: String,
	p_revenue_contributions_text: String,
	p_operating_cost_contributions_text: String,
	p_project_cost_contributions_text: String,
	p_progress_contributions_text: String,
	p_completion_revenue_text: String
) -> void:
	_title_text = p_title_text
	_date_text = p_date_text
	_cash_text = p_cash_text
	_monthly_revenue_text = p_monthly_revenue_text
	_monthly_operating_cost_text = p_monthly_operating_cost_text
	_project_text = p_project_text
	_action_text = p_action_text
	_start_project_available = p_start_project_available
	_cash_explanation_text = p_cash_explanation_text
	_revenue_contributions_text = p_revenue_contributions_text
	_operating_cost_contributions_text = p_operating_cost_contributions_text
	_project_cost_contributions_text = p_project_cost_contributions_text
	_progress_contributions_text = p_progress_contributions_text
	_completion_revenue_text = p_completion_revenue_text


func get_title_text() -> String:
	return _title_text


func get_date_text() -> String:
	return _date_text


func get_cash_text() -> String:
	return _cash_text


func get_monthly_revenue_text() -> String:
	return _monthly_revenue_text


func get_monthly_operating_cost_text() -> String:
	return _monthly_operating_cost_text


func get_project_text() -> String:
	return _project_text


func get_action_text() -> String:
	return _action_text


func is_start_project_available() -> bool:
	return _start_project_available


func get_cash_explanation_text() -> String:
	return _cash_explanation_text


func get_revenue_contributions_text() -> String:
	return _revenue_contributions_text


func get_operating_cost_contributions_text() -> String:
	return _operating_cost_contributions_text


func get_project_cost_contributions_text() -> String:
	return _project_cost_contributions_text


func get_progress_contributions_text() -> String:
	return _progress_contributions_text


func get_completion_revenue_text() -> String:
	return _completion_revenue_text
