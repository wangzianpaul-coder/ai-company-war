class_name MarketState
extends RefCounted


const TOTAL_BASIS_POINTS: int = 10_000

## Fixed monthly demand split and recurring market economics use integer units,
## cents and basis points. Raw constructor values are retained so MarketSystem
## can reject malformed fixtures without silently clamping them.
var _consumer_workload_units_per_month: int
var _developer_api_workload_units_per_month: int
var _consumer_service_allocation_bps: int
var _consumer_player_share_bps: int
var _developer_api_player_share_bps: int
var _consumer_addressable_monthly_revenue_cents: int
var _developer_api_addressable_monthly_revenue_cents: int
var _consumer_full_service_growth_bps: int
var _developer_api_full_service_growth_bps: int
var _consumer_unmet_penalty_bps_per_unit: int
var _developer_api_unmet_penalty_bps_per_unit: int
var _consumer_current_served_units_per_month: int
var _developer_api_current_served_units_per_month: int
var _consumer_current_market_revenue_cents: int
var _developer_api_current_market_revenue_cents: int
var _consumer_cumulative_served_compute_unit_months: int
var _consumer_cumulative_unmet_compute_unit_months: int
var _developer_api_cumulative_served_compute_unit_months: int
var _developer_api_cumulative_unmet_compute_unit_months: int


## Stores the two fixed markets. The all-zero default is valid and inert.
func _init(
	p_consumer_workload_units_per_month: int = 0,
	p_developer_api_workload_units_per_month: int = 0,
	p_consumer_service_allocation_bps: int = 0,
	p_consumer_player_share_bps: int = 0,
	p_developer_api_player_share_bps: int = 0,
	p_consumer_addressable_monthly_revenue_cents: int = 0,
	p_developer_api_addressable_monthly_revenue_cents: int = 0,
	p_consumer_full_service_growth_bps: int = 0,
	p_developer_api_full_service_growth_bps: int = 0,
	p_consumer_unmet_penalty_bps_per_unit: int = 0,
	p_developer_api_unmet_penalty_bps_per_unit: int = 0,
	p_consumer_current_served_units_per_month: int = 0,
	p_developer_api_current_served_units_per_month: int = 0,
	p_consumer_current_market_revenue_cents: int = 0,
	p_developer_api_current_market_revenue_cents: int = 0,
	p_consumer_cumulative_served_compute_unit_months: int = 0,
	p_consumer_cumulative_unmet_compute_unit_months: int = 0,
	p_developer_api_cumulative_served_compute_unit_months: int = 0,
	p_developer_api_cumulative_unmet_compute_unit_months: int = 0
) -> void:
	_consumer_workload_units_per_month = p_consumer_workload_units_per_month
	_developer_api_workload_units_per_month = p_developer_api_workload_units_per_month
	_consumer_service_allocation_bps = p_consumer_service_allocation_bps
	_consumer_player_share_bps = p_consumer_player_share_bps
	_developer_api_player_share_bps = p_developer_api_player_share_bps
	_consumer_addressable_monthly_revenue_cents = (
		p_consumer_addressable_monthly_revenue_cents
	)
	_developer_api_addressable_monthly_revenue_cents = (
		p_developer_api_addressable_monthly_revenue_cents
	)
	_consumer_full_service_growth_bps = p_consumer_full_service_growth_bps
	_developer_api_full_service_growth_bps = p_developer_api_full_service_growth_bps
	_consumer_unmet_penalty_bps_per_unit = p_consumer_unmet_penalty_bps_per_unit
	_developer_api_unmet_penalty_bps_per_unit = p_developer_api_unmet_penalty_bps_per_unit
	_consumer_current_served_units_per_month = p_consumer_current_served_units_per_month
	_developer_api_current_served_units_per_month = (
		p_developer_api_current_served_units_per_month
	)
	_consumer_current_market_revenue_cents = p_consumer_current_market_revenue_cents
	_developer_api_current_market_revenue_cents = p_developer_api_current_market_revenue_cents
	_consumer_cumulative_served_compute_unit_months = (
		p_consumer_cumulative_served_compute_unit_months
	)
	_consumer_cumulative_unmet_compute_unit_months = (
		p_consumer_cumulative_unmet_compute_unit_months
	)
	_developer_api_cumulative_served_compute_unit_months = (
		p_developer_api_cumulative_served_compute_unit_months
	)
	_developer_api_cumulative_unmet_compute_unit_months = (
		p_developer_api_cumulative_unmet_compute_unit_months
	)


## Returns a full independent copy of configuration, current values and totals.
func copy() -> MarketState:
	return MarketState.new(
		_consumer_workload_units_per_month,
		_developer_api_workload_units_per_month,
		_consumer_service_allocation_bps,
		_consumer_player_share_bps,
		_developer_api_player_share_bps,
		_consumer_addressable_monthly_revenue_cents,
		_developer_api_addressable_monthly_revenue_cents,
		_consumer_full_service_growth_bps,
		_developer_api_full_service_growth_bps,
		_consumer_unmet_penalty_bps_per_unit,
		_developer_api_unmet_penalty_bps_per_unit,
		_consumer_current_served_units_per_month,
		_developer_api_current_served_units_per_month,
		_consumer_current_market_revenue_cents,
		_developer_api_current_market_revenue_cents,
		_consumer_cumulative_served_compute_unit_months,
		_consumer_cumulative_unmet_compute_unit_months,
		_developer_api_cumulative_served_compute_unit_months,
		_developer_api_cumulative_unmet_compute_unit_months
	)


func get_consumer_workload_units_per_month() -> int:
	return _consumer_workload_units_per_month


func get_developer_api_workload_units_per_month() -> int:
	return _developer_api_workload_units_per_month


func get_consumer_service_allocation_bps() -> int:
	return _consumer_service_allocation_bps


func get_developer_api_service_allocation_bps() -> int:
	return TOTAL_BASIS_POINTS - _consumer_service_allocation_bps


func get_consumer_player_share_bps() -> int:
	return _consumer_player_share_bps


func get_consumer_outside_share_bps() -> int:
	return TOTAL_BASIS_POINTS - _consumer_player_share_bps


func get_developer_api_player_share_bps() -> int:
	return _developer_api_player_share_bps


func get_developer_api_outside_share_bps() -> int:
	return TOTAL_BASIS_POINTS - _developer_api_player_share_bps


func get_consumer_addressable_monthly_revenue_cents() -> int:
	return _consumer_addressable_monthly_revenue_cents


func get_developer_api_addressable_monthly_revenue_cents() -> int:
	return _developer_api_addressable_monthly_revenue_cents


func get_consumer_full_service_growth_bps() -> int:
	return _consumer_full_service_growth_bps


func get_developer_api_full_service_growth_bps() -> int:
	return _developer_api_full_service_growth_bps


func get_consumer_unmet_penalty_bps_per_unit() -> int:
	return _consumer_unmet_penalty_bps_per_unit


func get_developer_api_unmet_penalty_bps_per_unit() -> int:
	return _developer_api_unmet_penalty_bps_per_unit


func get_consumer_current_served_units_per_month() -> int:
	return _consumer_current_served_units_per_month


func get_developer_api_current_served_units_per_month() -> int:
	return _developer_api_current_served_units_per_month


func get_consumer_current_market_revenue_cents() -> int:
	return _consumer_current_market_revenue_cents


func get_developer_api_current_market_revenue_cents() -> int:
	return _developer_api_current_market_revenue_cents


func get_consumer_cumulative_served_compute_unit_months() -> int:
	return _consumer_cumulative_served_compute_unit_months


func get_consumer_cumulative_unmet_compute_unit_months() -> int:
	return _consumer_cumulative_unmet_compute_unit_months


func get_developer_api_cumulative_served_compute_unit_months() -> int:
	return _developer_api_cumulative_served_compute_unit_months


func get_developer_api_cumulative_unmet_compute_unit_months() -> int:
	return _developer_api_cumulative_unmet_compute_unit_months


## Commits one fully validated month. MarketSystem calculates every argument first.
func _commit_month(
	p_consumer_player_share_bps: int,
	p_developer_api_player_share_bps: int,
	p_consumer_current_served_units_per_month: int,
	p_developer_api_current_served_units_per_month: int,
	p_consumer_current_market_revenue_cents: int,
	p_developer_api_current_market_revenue_cents: int,
	p_consumer_cumulative_served_compute_unit_months: int,
	p_consumer_cumulative_unmet_compute_unit_months: int,
	p_developer_api_cumulative_served_compute_unit_months: int,
	p_developer_api_cumulative_unmet_compute_unit_months: int
) -> void:
	_consumer_player_share_bps = p_consumer_player_share_bps
	_developer_api_player_share_bps = p_developer_api_player_share_bps
	_consumer_current_served_units_per_month = p_consumer_current_served_units_per_month
	_developer_api_current_served_units_per_month = (
		p_developer_api_current_served_units_per_month
	)
	_consumer_current_market_revenue_cents = p_consumer_current_market_revenue_cents
	_developer_api_current_market_revenue_cents = p_developer_api_current_market_revenue_cents
	_consumer_cumulative_served_compute_unit_months = (
		p_consumer_cumulative_served_compute_unit_months
	)
	_consumer_cumulative_unmet_compute_unit_months = (
		p_consumer_cumulative_unmet_compute_unit_months
	)
	_developer_api_cumulative_served_compute_unit_months = (
		p_developer_api_cumulative_served_compute_unit_months
	)
	_developer_api_cumulative_unmet_compute_unit_months = (
		p_developer_api_cumulative_unmet_compute_unit_months
	)
