'use strict';

function fail(message) { return { ok: false, error: message }; }
function ok(value) {
	if (value == null) value = {};
	value.ok = true;
	return value;
}
function is_digit(value) {
	return value != null && value != '' && match(value, /^[0-9]+$/) != null;
}
function valid_interval(value) {
	if (value == null || value == '' || value == '0') return true;
	if (!is_digit(value)) return false;
	let number = int(value);
	return number >= 1 && number <= 8760;
}

export { fail, ok, is_digit, valid_interval };
