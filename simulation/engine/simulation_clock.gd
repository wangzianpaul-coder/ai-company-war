class_name SimulationClock
extends RefCounted


const START_YEAR: int = 2026
const START_MONTH: int = 1
const MONTHS_PER_YEAR: int = 12
const MONTHS_PER_QUARTER: int = 3
const _MAX_ELAPSED_MONTHS: int = 9_223_372_036_854_775_807

## Complete integer months elapsed since January 2026.
## The invariant is 0 <= _elapsed_months <= the largest signed 64-bit integer.
var _elapsed_months: int = 0


## Returns the complete elapsed-month value needed for an independent state copy.
func get_elapsed_months() -> int:
	return _elapsed_months


## Returns the calendar year derived only from elapsed integer months.
@warning_ignore("integer_division")
func get_year() -> int:
	return START_YEAR + (_elapsed_months / MONTHS_PER_YEAR)


## Returns the one-based calendar month in the range 1 through 12.
func get_month() -> int:
	return START_MONTH + (_elapsed_months % MONTHS_PER_YEAR)


## Returns the one-based quarter derived from the current month.
@warning_ignore("integer_division")
func get_quarter() -> int:
	return ((get_month() - 1) / MONTHS_PER_QUARTER) + 1


## Advances exactly one base simulation month.
func advance_month() -> bool:
	return advance_months(1)


## Atomically advances a non-negative number of complete months.
## Invalid input or signed-integer overflow returns false without changing the clock.
func advance_months(month_count: int) -> bool:
	if _elapsed_months < 0:
		return false
	if month_count < 0:
		return false
	if month_count > _MAX_ELAPSED_MONTHS - _elapsed_months:
		return false

	_elapsed_months += month_count
	return true
