class_name ComputeState
extends RefCounted


## Monthly capacity is a non-bankable flow; cumulative fields use compute-unit-months.
var _total_units_per_month: int
var _reserve_units_per_month: int
var _inference_workload_units_per_month: int
var _training_allocation_units_per_month: int
var _cumulative_training_compute_unit_months: int
var _cumulative_served_inference_compute_unit_months: int
var _cumulative_unmet_inference_compute_unit_months: int


## Stores raw typed values so systems can reject invalid fixtures without hidden clamps.
func _init(
	p_total_units_per_month: int = 0,
	p_reserve_units_per_month: int = 0,
	p_inference_workload_units_per_month: int = 0,
	p_training_allocation_units_per_month: int = 0,
	p_cumulative_training_compute_unit_months: int = 0,
	p_cumulative_served_inference_compute_unit_months: int = 0,
	p_cumulative_unmet_inference_compute_unit_months: int = 0
) -> void:
	_total_units_per_month = p_total_units_per_month
	_reserve_units_per_month = p_reserve_units_per_month
	_inference_workload_units_per_month = p_inference_workload_units_per_month
	_training_allocation_units_per_month = p_training_allocation_units_per_month
	_cumulative_training_compute_unit_months = p_cumulative_training_compute_unit_months
	_cumulative_served_inference_compute_unit_months = (
		p_cumulative_served_inference_compute_unit_months
	)
	_cumulative_unmet_inference_compute_unit_months = (
		p_cumulative_unmet_inference_compute_unit_months
	)


## Returns a full independent copy, including every cumulative total.
func copy() -> ComputeState:
	return ComputeState.new(
		_total_units_per_month,
		_reserve_units_per_month,
		_inference_workload_units_per_month,
		_training_allocation_units_per_month,
		_cumulative_training_compute_unit_months,
		_cumulative_served_inference_compute_unit_months,
		_cumulative_unmet_inference_compute_unit_months
	)


func get_total_units_per_month() -> int:
	return _total_units_per_month


func get_reserve_units_per_month() -> int:
	return _reserve_units_per_month


func get_inference_workload_units_per_month() -> int:
	return _inference_workload_units_per_month


func get_training_allocation_units_per_month() -> int:
	return _training_allocation_units_per_month


## Returns zero for a malformed raw state so read-only presentation stays safe.
func get_allocatable_capacity_units_per_month() -> int:
	if (
		_total_units_per_month < 0
		or _reserve_units_per_month < 0
		or _reserve_units_per_month > _total_units_per_month
	):
		return 0
	return _total_units_per_month - _reserve_units_per_month


## Derives online inference capacity without exposing arithmetic to Application or UI.
func get_inference_allocation_units_per_month() -> int:
	var allocatable_capacity: int = get_allocatable_capacity_units_per_month()
	if (
		_training_allocation_units_per_month < 0
		or _training_allocation_units_per_month > allocatable_capacity
	):
		return 0
	return allocatable_capacity - _training_allocation_units_per_month


## Canonically derives the non-bankable inference workload served this month.
## Malformed raw workloads return zero; systems still reject the malformed state.
func get_served_inference_units_per_month() -> int:
	if _inference_workload_units_per_month < 0:
		return 0
	var inference_capacity: int = get_inference_allocation_units_per_month()
	return mini(inference_capacity, _inference_workload_units_per_month)


## Canonically derives the inference workload left unmet this month.
## Malformed raw workloads return zero; systems still reject the malformed state.
func get_unmet_inference_units_per_month() -> int:
	if _inference_workload_units_per_month < 0:
		return 0
	return (
		_inference_workload_units_per_month
		- get_served_inference_units_per_month()
	)


func get_cumulative_training_compute_unit_months() -> int:
	return _cumulative_training_compute_unit_months


func get_cumulative_served_inference_compute_unit_months() -> int:
	return _cumulative_served_inference_compute_unit_months


func get_cumulative_unmet_inference_compute_unit_months() -> int:
	return _cumulative_unmet_inference_compute_unit_months


## Commits an allocation only after ComputeSystem has validated the entire state.
func _commit_training_allocation(p_training_units_per_month: int) -> void:
	_training_allocation_units_per_month = p_training_units_per_month


## Commits all cumulative results together after every signed-64 check succeeds.
func _commit_cumulative_results(
	p_training_compute_unit_months: int,
	p_served_inference_compute_unit_months: int,
	p_unmet_inference_compute_unit_months: int
) -> void:
	_cumulative_training_compute_unit_months = p_training_compute_unit_months
	_cumulative_served_inference_compute_unit_months = (
		p_served_inference_compute_unit_months
	)
	_cumulative_unmet_inference_compute_unit_months = p_unmet_inference_compute_unit_months
