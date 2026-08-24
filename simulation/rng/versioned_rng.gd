class_name VersionedRng
extends RefCounted


const ALGORITHM_VERSION_ONE: int = 1
const MIN_STATE: int = 1
const MAX_STATE: int = 2_147_483_646
const MULTIPLIER: int = 48_271
const MODULUS: int = 2_147_483_647
const NOISE_UPPER_BOUND: int = 10


class DrawResult:
	extends RefCounted

	enum ErrorCode {
		NONE,
		INVALID_VERSION,
		INVALID_STATE,
	}

	var _error_code: ErrorCode
	var _next_state: int
	var _noise: int

	func _init(
		p_error_code: ErrorCode,
		p_next_state: int = 0,
		p_noise: int = 0
	) -> void:
		_error_code = p_error_code
		if p_error_code == ErrorCode.NONE:
			_next_state = p_next_state
			_noise = p_noise

	func is_successful() -> bool:
		return _error_code == ErrorCode.NONE

	func get_error_code() -> ErrorCode:
		return _error_code

	func get_next_state() -> int:
		return _next_state

	func get_noise() -> int:
		return _noise


## Advances one Park-Miller version-one state and returns noise in [0, 9].
## The maximum product is safely inside a signed 64-bit integer.
func draw_noise(algorithm_version: int, current_state: int) -> DrawResult:
	if algorithm_version != ALGORITHM_VERSION_ONE:
		return DrawResult.new(DrawResult.ErrorCode.INVALID_VERSION)
	if current_state < MIN_STATE or current_state > MAX_STATE:
		return DrawResult.new(DrawResult.ErrorCode.INVALID_STATE)
	var next_state: int = (current_state * MULTIPLIER) % MODULUS
	var noise: int = next_state % NOISE_UPPER_BOUND
	return DrawResult.new(DrawResult.ErrorCode.NONE, next_state, noise)
