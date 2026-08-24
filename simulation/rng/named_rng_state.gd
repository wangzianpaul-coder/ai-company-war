class_name NamedRngState
extends RefCounted


const ALGORITHM_VERSION_ONE: int = 1
const MIN_ACTIVE_VALUE: int = 1
const MAX_ACTIVE_VALUE: int = 2_147_483_646
const ACTIVE_VALUE_COUNT: int = 2_147_483_646
const EVENTS_STREAM_OFFSET: int = 4
const MARKET_STREAM_OFFSET: int = 6

var _master_seed: int
var _algorithm_version: int
var _ai_stream_state: int
var _events_stream_state: int
var _market_stream_state: int


## Stores raw values so invalid fixtures can be rejected at a typed boundary.
## The all-zero default is the one canonical inactive value.
func _init(
	p_master_seed: int = 0,
	p_algorithm_version: int = 0,
	p_ai_stream_state: int = 0,
	p_events_stream_state: int = 0,
	p_market_stream_state: int = 0
) -> void:
	_master_seed = p_master_seed
	_algorithm_version = p_algorithm_version
	_ai_stream_state = p_ai_stream_state
	_events_stream_state = p_events_stream_state
	_market_stream_state = p_market_stream_state


## Creates fresh version-one named streams from one checked master value.
## No return annotation avoids a static self-reference parser edge case.
static func create_fresh_version_one(p_master_seed: int):
	if not _is_active_value_valid(p_master_seed):
		return null
	var events_state: int = 1 + (
		(p_master_seed - 1 + EVENTS_STREAM_OFFSET) % ACTIVE_VALUE_COUNT
	)
	var market_state: int = 1 + (
		(p_master_seed - 1 + MARKET_STREAM_OFFSET) % ACTIVE_VALUE_COUNT
	)
	return new(
		p_master_seed,
		ALGORITHM_VERSION_ONE,
		p_master_seed,
		events_state,
		market_state
	)


## Reconstructs independently advanced streams without deriving them again.
## No return annotation avoids a static self-reference parser edge case.
static func create_checked_current(
	p_master_seed: int,
	p_algorithm_version: int,
	p_ai_stream_state: int,
	p_events_stream_state: int,
	p_market_stream_state: int
):
	if p_algorithm_version != ALGORITHM_VERSION_ONE:
		return null
	if (
		not _is_active_value_valid(p_master_seed)
		or not _is_active_value_valid(p_ai_stream_state)
		or not _is_active_value_valid(p_events_stream_state)
		or not _is_active_value_valid(p_market_stream_state)
	):
		return null
	return new(
		p_master_seed,
		p_algorithm_version,
		p_ai_stream_state,
		p_events_stream_state,
		p_market_stream_state
	)


## Returns an independent valid copy, or null for a malformed raw fixture.
func copy():
	if is_canonical_inactive():
		return new()
	return create_checked_current(
		_master_seed,
		_algorithm_version,
		_ai_stream_state,
		_events_stream_state,
		_market_stream_state
	)


func get_master_seed() -> int:
	return _master_seed


func get_algorithm_version() -> int:
	return _algorithm_version


func get_ai_stream_state() -> int:
	return _ai_stream_state


func get_events_stream_state() -> int:
	return _events_stream_state


func get_market_stream_state() -> int:
	return _market_stream_state


func is_canonical_inactive() -> bool:
	return (
		_master_seed == 0
		and _algorithm_version == 0
		and _ai_stream_state == 0
		and _events_stream_state == 0
		and _market_stream_state == 0
	)


func is_valid_active_version_one() -> bool:
	return (
		_algorithm_version == ALGORITHM_VERSION_ONE
		and _is_active_value_valid(_master_seed)
		and _is_active_value_valid(_ai_stream_state)
		and _is_active_value_valid(_events_stream_state)
		and _is_active_value_valid(_market_stream_state)
	)


static func _is_active_value_valid(value: int) -> bool:
	return value >= MIN_ACTIVE_VALUE and value <= MAX_ACTIVE_VALUE
