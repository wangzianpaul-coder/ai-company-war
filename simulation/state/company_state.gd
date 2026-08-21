class_name CompanyState
extends RefCounted


## Signed cash and non-negative monthly flow values, all in integer cents.
var _cash_cents: int
var _monthly_revenue_cents: int
var _monthly_operating_cost_cents: int


## Creates signed cash and monthly revenue/cost values in integer cents.
## Systems reject negative flow values before any mutation.
func _init(
	p_cash_cents: int = 0,
	p_monthly_revenue_cents: int = 0,
	p_monthly_operating_cost_cents: int = 0
) -> void:
	_cash_cents = p_cash_cents
	_monthly_revenue_cents = p_monthly_revenue_cents
	_monthly_operating_cost_cents = p_monthly_operating_cost_cents


func get_cash_cents() -> int:
	return _cash_cents


func get_monthly_revenue_cents() -> int:
	return _monthly_revenue_cents


func get_monthly_operating_cost_cents() -> int:
	return _monthly_operating_cost_cents


## Commits values that a system has already validated as one atomic operation.
func _commit_financials(p_cash_cents: int, p_monthly_revenue_cents: int) -> void:
	_cash_cents = p_cash_cents
	_monthly_revenue_cents = p_monthly_revenue_cents
