class_name ProjectState
extends RefCounted


## Lifecycle of the single project slot.
enum Lifecycle {
	NOT_STARTED,
	ACTIVE,
	COMPLETED,
}

var _project_id: StringName
var _lifecycle: Lifecycle
var _required_months: int
var _progress_months: int
var _monthly_cost_cents: int
var _completion_monthly_revenue_delta_cents: int


## Creates one project with duration/progress in months and financial values in cents.
## ProjectSystem validates the complete lifecycle state before any mutation.
func _init(
	p_project_id: StringName = &"project_slot",
	p_required_months: int = 1,
	p_monthly_cost_cents: int = 0,
	p_completion_monthly_revenue_delta_cents: int = 0,
	p_lifecycle: Lifecycle = Lifecycle.NOT_STARTED,
	p_progress_months: int = 0
) -> void:
	_project_id = p_project_id
	_required_months = p_required_months
	_monthly_cost_cents = p_monthly_cost_cents
	_completion_monthly_revenue_delta_cents = p_completion_monthly_revenue_delta_cents
	_lifecycle = p_lifecycle
	_progress_months = p_progress_months


func get_project_id() -> StringName:
	return _project_id


func get_lifecycle() -> Lifecycle:
	return _lifecycle


func get_required_months() -> int:
	return _required_months


func get_progress_months() -> int:
	return _progress_months


func get_monthly_cost_cents() -> int:
	return _monthly_cost_cents


func get_completion_monthly_revenue_delta_cents() -> int:
	return _completion_monthly_revenue_delta_cents


## Starts a structurally valid project after its system has checked the lifecycle.
func _commit_started() -> void:
	_lifecycle = Lifecycle.ACTIVE


## Commits exactly one validated month and its resulting lifecycle.
func _commit_advanced(p_progress_months: int, p_is_completed: bool) -> void:
	_progress_months = p_progress_months
	_lifecycle = Lifecycle.COMPLETED if p_is_completed else Lifecycle.ACTIVE
