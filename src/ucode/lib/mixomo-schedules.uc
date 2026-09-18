'use strict';

import {
	SCHED_DIR, TIME_FILE, TRIGGER_FILE, DEFAULT_FILE,
	read_file, write_file, mkdir_p, clean_name, valid_name,
	read_table, write_table
} from 'mixomo';

const ORDER_DIR = '/etc/mixomo/order';

function fail(message) { return { ok: false, error: message }; }
function ok(value) { if (value == null) value = {}; value.ok = true; return value; }
function mark_changed() { mkdir_p('/var/run/mixomo-schedule'); write_file('/var/run/mixomo-schedule/.schedule_changed', time() + '\n'); }
function is_digit(value) { return value != null && value != '' && match(value, /^[0-9]+$/); }
function order_read(name) {
	let values = [];
	let content = read_file(ORDER_DIR + '/' + name);
	if (content != null) {
		let lines = split(content, '\n');
		for (let i = 0; i < length(lines); i++) {
			let line = lines[i];
			if (line != '') push(values, line);
		}
	}
	return values;
}
function order_write(name, values) {
	mkdir_p(ORDER_DIR);
	write_file(ORDER_DIR + '/' + name, values + '\n');
	return ok();
}
function rename_order(name, old_name, new_name) {
	let values = order_read(name);
	for (let i = 0; i < length(values); i++)
		if (values[i] == old_name) values[i] = new_name;
	mkdir_p(ORDER_DIR);
	write_file(ORDER_DIR + '/' + name, join('\n', values) + '\n');
}
function normalize(value, minimum, maximum) {
	if (value == null || value == '' || value == 'all' || value == '-') return 'all';
	let out = [];
	let parts = split(value, ',');
	for (let i = 0; i < length(parts); i++) {
		let part = parts[i];
		if (!is_digit(part)) continue;
		let number = int(part);
		if (number >= minimum && number <= maximum) push(out, '' + number);
	}
	return length(out) == 0 ? 'all' : join(',', out);
}
function time_rows() {
	let out = [];
	let table = read_table(TIME_FILE);
	for (let i = 0; i < length(table); i++) {
		let row = table[i];
		if (row == null || length(row) == 0 || row[0] == '') continue;
		push(out, {
			name: row[0],
			enabled: row[1] == '1' ? 1 : 0,
			profile: row[2] == null ? '' : row[2],
			start: row[3] == null ? '' : row[3],
			end: row[4] == null ? '' : row[4],
			days: row[5] == null || row[5] == '' ? 'all' : row[5],
			dom: row[6] == null || row[6] == '' ? 'all' : row[6],
			months: row[7] == null || row[7] == '' ? 'all' : row[7]
		});
	}
	return out;
}
function trigger_rows() {
	let out = [];
	let table = read_table(TRIGGER_FILE);
	for (let i = 0; i < length(table); i++) {
		let row = table[i];
		if (row == null || length(row) == 0 || row[0] == '') continue;
		push(out, {
			name: row[0],
			enabled: row[1] == '1' ? 1 : 0,
			urls: row[2] == null ? '' : row[2],
			interval: row[3] == null || row[3] == '' ? '3' : row[3],
			fallback: row[4] == null ? '' : row[4],
			primary: row[5] == null ? '' : row[5],
			threshold: row[6] == null || row[6] == '' ? '1' : row[6],
			mode: row[7] == 'direct' ? 'direct' : 'mihomo'
		});
	}
	return out;
}
function clean_schedule(req) {
	let type = req.args.type || '';
	let name = clean_name(req.args.name || '');
	if (!valid_name(name)) return fail('Недопустимое имя расписания');
	if (type != 'time' && type != 'trigger') return fail('Неизвестный тип расписания');
	return { type: type, name: name };
}
function save(req) {
	let data = clean_schedule(req);
	if (data.ok == false) return data;
	let type = data.type;
	let name = data.name;
	let old_name = clean_name(req.args.old || '');
	if (old_name != '' && !valid_name(old_name)) return fail('Недопустимое старое имя расписания');
	let key = old_name != '' ? old_name : name;
	let enabled = req.args.enabled ? 1 : 0;
	let path = type == 'time' ? TIME_FILE : TRIGGER_FILE;
	mkdir_p(SCHED_DIR);
	if (type == 'time') {
		let profile = clean_name(req.args.profile || '');
		if (profile == '') return fail('Выберите профиль');
		let start = req.args.start || '';
		let end = req.args.end || '';
		if (start != '' && match(start, /^[0-9]{2}:[0-9]{2}$/) == null) return fail('Некорректное время начала');
		if (end != '' && match(end, /^[0-9]{2}:[0-9]{2}$/) == null) return fail('Некорректное время окончания');
		let row = [name, enabled, profile, start, end, normalize(req.args.days || 'all', 0, 6), normalize(req.args.dom || 'all', 1, 31), normalize(req.args.months || 'all', 1, 12)];
		let rows = [];
		let found = false;
		let table = read_table(path);
		for (let i = 0; i < length(table); i++) {
			let current = table[i];
			if (current[0] == name && key != name) return fail('Расписание с таким именем уже существует');
			if (current[0] == key) { push(rows, row); found = true; }
			else push(rows, current);
		}
		if (old_name != '' && !found) return fail('Расписание не найдено');
		if (!found) push(rows, row);
		write_table(path, rows);
	} else {
		let urls = req.args.urls || '';
		if (urls == '') return fail('Укажите хотя бы один URL');
		let interval = is_digit(req.args.interval) && req.args.interval > 0 ? req.args.interval : '3';
		let threshold = is_digit(req.args.threshold) && req.args.threshold > 0 ? req.args.threshold : '1';
		let mode = req.args.mode == 'direct' ? 'direct' : 'mihomo';
		let row = [name, enabled, urls, interval, req.args.fallback || '', req.args.primary || '', threshold, mode];
		let rows = [];
		let found = false;
		let table = read_table(path);
		for (let i = 0; i < length(table); i++) {
			let current = table[i];
			if (current[0] == name && key != name) return fail('Расписание с таким именем уже существует');
			if (current[0] == key) { push(rows, row); found = true; }
			else push(rows, current);
		}
		if (old_name != '' && !found) return fail('Расписание не найдено');
		if (!found) push(rows, row);
		write_table(path, rows);
	}
	mark_changed();
	if (old_name != '' && old_name != name)
		rename_order(type == 'time' ? 'sched_time' : 'sched_trigger', old_name, name);
	return ok();
}
function remove(req) {
	let data = clean_schedule(req);
	if (data.ok == false) return data;
	let path = data.type == 'time' ? TIME_FILE : TRIGGER_FILE;
	let rows = [];
	let table = read_table(path);
	for (let i = 0; i < length(table); i++) {
		let row = table[i];
		if (row[0] != data.name) push(rows, row);
	}
	write_table(path, rows);
	system([ '/bin/rm', '-f', SCHED_DIR + '/.last_' + data.name, SCHED_DIR + '/.fails_' + data.name, '/var/run/mixomo-schedule/.last_' + data.name, '/var/run/mixomo-schedule/.fails_' + data.name, '/var/run/mixomo-schedule/.success_' + data.name ]);
	return ok();
}
function set_enabled(req) {
	let data = clean_schedule(req);
	if (data.ok == false) return data;
	let path = data.type == 'time' ? TIME_FILE : TRIGGER_FILE;
	let rows = [];
	let found = false;
	let table = read_table(path);
	for (let i = 0; i < length(table); i++) {
		let row = table[i];
		if (row[0] == data.name) { row[1] = req.args.enabled ? '1' : '0'; found = true; }
		push(rows, row);
	}
	if (!found) return fail('Расписание не найдено');
	write_table(path, rows);
	mark_changed();
	return ok();
}
const methods = {
	list: { call: function() { return ok({ 'default': read_file(DEFAULT_FILE) == null ? '' : trim(read_file(DEFAULT_FILE)), time: time_rows(), trigger: trigger_rows(), timeOrder: order_read('sched_time'), triggerOrder: order_read('sched_trigger') }); } },
	'default': { args: { profile: 'string' }, call: function(req) { let profile = clean_name(req.args.profile || ''); mkdir_p(SCHED_DIR); write_file(DEFAULT_FILE, profile + '\n'); return ok(); } },
	save: { args: { type: 'string', name: 'string', enabled: true, profile: 'string', start: 'string', end: 'string', days: 'string', dom: 'string', months: 'string', urls: 'string', interval: 'string', fallback: 'string', primary: 'string', threshold: 'string', old: 'string', mode: 'string' }, call: save },
	'delete': { args: { type: 'string', name: 'string' }, call: remove },
	set_enabled: { args: { type: 'string', name: 'string', enabled: true }, call: set_enabled }
};
export { methods };
