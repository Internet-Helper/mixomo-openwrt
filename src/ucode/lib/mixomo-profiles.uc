'use strict';

import { popen, unlink } from 'fs';
import {
	MIXOMO_PROFILES, STATE_FILE, ACTIVE_FILE, PROFILES_DIR, RULES_DIR, RULES_STATE,
	MAIN_CONFIG, DEFAULT_CONFIG, MIHOMO_BIN, API_URL,
	SCHED_DIR, TIME_FILE, TRIGGER_FILE, DEFAULT_FILE,
	read_file, write_file, mkdir_p, file_exists, clean_name, valid_name, download_to,
	read_table, write_table, lookup_row, state_update, state_touch,
	extract_section, remove_section, extract_anchor_sections, extract_external_anchor_sections,
	prefix_before_proxies, from_proxies, strip_trailing_blanks, append_block, has_section,
	build_full_config, build_selected_config, build_refresh_full_config,
	build_refresh_selected_config, normalize_config, test_config,
	current_active, apply_profile, read_dashboard_panel, set_dashboard_panel
} from 'mixomo';

const VALID_SECTIONS = [ 'proxies', 'proxy-groups', 'proxy-providers', 'rule-providers', 'rules' ];
const ORDER_DIR = '/etc/mixomo/order';
const SUBSCRIPTIONS_DIR = '/etc/mixomo/subscriptions';
const SUBSCRIPTION_PROVIDERS_DIR = SUBSCRIPTIONS_DIR + '/providers';
const HAPPY_KEY_FILE = '/etc/mixomo/secrets/happy-decoder.key';
const SUBSCRIPTION_TEMPLATE = '/etc/mixomo/templates/subscription-template.yaml';

function shlex(s) {
	return "'" + replace(s, "'", "'\\''") + "'";
}

function secure_temp(prefix) {
	let p = popen('/bin/mktemp ' + shlex('/tmp/' + prefix + '.XXXXXX'), 'r');
	if (p == null) return '';
	let path = trim(p.read('all') || '');
	p.close();
	return path;
}

function has_suffix(s, suf) {
	return length(s) >= length(suf) && substr(s, length(s) - length(suf)) == suf;
}

function fail(msg) { return { ok: false, error: msg }; }
function ok(obj) { if (obj == null) obj = {}; obj.ok = true; return obj; }

function with_defaults(args, names) {
	if (args == null) return args;
	for (let di = 0; di < length(names); di++) {
		let key = names[di];
		if (args[key] == null) args[key] = '';
	}
	return args;
}

function is_digit(s) {
	return (s != null && s != '' && match(s, /^[0-9]+$/));
}

function valid_interval(interval) {
	if (interval == null || interval == '' || interval == '0') return true;
	if (!is_digit(interval)) return false;
	let i = int(interval);
	return (i >= 1 && i <= 8760);
}

function list_dir(path) {
	let out = [];
	let p = popen('/bin/ls -1 ' + shlex(path) + ' 2>/dev/null', 'r');
	if (p != null) {
		let s = p.read('all');
		p.close();
		if (s != null) {
			let lines = split(s, '\n');
			for (let i = 0; i < length(lines); i++) {
				let line = lines[i];
				if (line != '')
					push(out, line);
			}
		}
	}
	return out;
}

function list_profiles() {
	let out = [];
	let files = list_dir(PROFILES_DIR + '/' );
	for (let i = 0; i < length(files); i++) {
		let f = files[i];
		if (f == '') continue;
		if (length(f) < 5 || !has_suffix(f, '.yaml')) continue;
		let base = substr(f, 0, length(f) - 5);
		push(out, base);
	}
	return out;
}

function list_rules() {
	let out = [];
	let files = list_dir(RULES_DIR + '/');
	for (let i = 0; i < length(files); i++) {
		let f = files[i];
		if (f != '' && (has_suffix(f, '.yaml') || has_suffix(f, '.txt')))
			push(out, f);
	}
	return out;
}

function order_read(name) {
	let s = read_file(ORDER_DIR + '/' + name);
	let out = [];
	if (s != null) {
		let lines = split(s, '\n');
		for (let i = 0; i < length(lines); i++) {
			let line = lines[i];
			if (line != '')
				push(out, line);
		}
	}
	return out;
}

function order_write(name, names) {
	system([ '/bin/mkdir', '-p', ORDER_DIR ]);
	write_file(ORDER_DIR + '/' + name, (names == null) ? '' : names);
	return ok();
}

function emit_list() {
	let active = current_active();
	let profiles = [];
	let names = list_profiles();
	for (let i = 0; i < length(names); i++) {
		let name = names[i];
		let row = lookup_row(STATE_FILE, name);
		push(profiles, {
			name: name,
			url: (row != null && row[1] != null) ? row[1] : '',
			interval: (row != null && row[2] != null) ? row[2] : '',
			updated: (row != null && row[3] != null) ? row[3] : '',
			sections: (row != null && row[4] != null) ? row[4] : '',
			source: (row != null && row[5] != null) ? row[5] : '',
			active: (active == name) ? 1 : 0
		});
	}
	let rules = [];
	let files = list_rules();
	for (let i = 0; i < length(files); i++) {
		let f = files[i];
		let row = lookup_row(RULES_STATE, f);
		push(rules, {
			name: f,
			url: (row != null && row[1] != null) ? row[1] : '',
			interval: (row != null && row[2] != null) ? row[2] : '',
			updated: (row != null && row[3] != null) ? row[3] : ''
		});
	}
	return ok({
		active: active,
		profiles: profiles,
		rules: rules,
		configsOrder: order_read('configs'),
		rulesOrder: order_read('rules'),
		schedTimeOrder: order_read('sched_time'),
		schedTriggerOrder: order_read('sched_trigger')
	});
}

function import_from(req, full) {
	let name = clean_name(req.args.name || '');
	if (!valid_name(name)) return fail('Недопустимое имя профиля');
	let interval = req.args.interval || '';
	if (interval != '' && interval != '0' && (int(interval) < 1 || int(interval) > 8760))
		return fail('Интервал от 1 до 8760 часов');

	let sections = full ? '' : (req.args.sections || '');
	if (!full) {
		let sel = [];
		let section_list = split(sections, ',');
		for (let i = 0; i < length(section_list); i++) {
			let s = section_list[i];
			if (index(VALID_SECTIONS, s) >= 0)
				push(sel, s);
		}
		if (length(sel) == 0) return fail('Выберите хотя бы одну секцию для импорта');
		sections = join(',', sel);
	}

	if (!file_exists(MAIN_CONFIG)) return fail('Основная конфигурация не найдена');

	let src = '/tmp/mixomo-import-' + time();
	if (req.args.url != null && req.args.url != '') {
		if (!download_to(req.args.url, src)) return fail('Не удалось скачать по ссылке');
	} else if (req.args.content != null && req.args.content != '') {
		write_file(src, req.args.content);
	} else {
		return fail('Укажите ссылку или содержимое файла');
	}
	let content = read_file(src);
	if (content == null) { unlink(src); return fail('Пустой ответ по ссылке'); }
	unlink(src);

	let tmp;
	if (full) {
		let built = build_full_config(content);
		if (built == null) return fail('Не удалось собрать конфигурацию');
		tmp = '/tmp/mixomo-build-' + time();
		write_file(tmp, built);
	} else {
		let built = build_selected_config(content, sections);
		if (built == null) return fail('Не удалось собрать конфигурацию');
		tmp = '/tmp/mixomo-build-' + time();
		write_file(tmp, built);
	}
	normalize_config(tmp);
	let t = test_config(tmp);
	if (!t.ok) {
		unlink(tmp);
		return fail('Конфигурация не прошла проверку Mihomo: ' + trim(t.output));
	}
	let prof = PROFILES_DIR + '/' + name + '.yaml';
	mkdir_p(PROFILES_DIR);
	if (read_file(prof) != null) { unlink(tmp); return fail('Профиль с таким именем уже существует'); }
	system([ '/bin/mv', tmp, prof ]);
	state_update(STATE_FILE, name, req.args.url || '', interval, (full ? '' : sections));
	return ok();
}

function do_import(req) { return import_from(req, false); }
function do_import_full(req) { return import_from(req, true); }

function do_create(req) {
	let name = clean_name(req.args.name || '');
	if (!valid_name(name)) return fail('Недопустимое имя профиля');
	let copy = !!req.args.copyActive;
	let base;
	if (copy) {
		if (!file_exists(MAIN_CONFIG)) return fail('Активная конфигурация не найдена');
		base = MAIN_CONFIG;
	} else if (file_exists(DEFAULT_CONFIG)) {
		base = DEFAULT_CONFIG;
	} else if (file_exists(PROFILES_DIR + '/default.yaml')) {
		base = PROFILES_DIR + '/default.yaml';
	} else {
		if (!file_exists(MAIN_CONFIG)) return fail('Основная конфигурация не найдена');
		base = MAIN_CONFIG;
	}
	let prof = PROFILES_DIR + '/' + name + '.yaml';
	if (file_exists(prof)) return fail('Профиль с таким именем уже существует');
	mkdir_p(PROFILES_DIR);
	write_file(prof, read_file(base));
	normalize_config(prof);
	state_update(STATE_FILE, name, '', '', '');
	return ok();
}

function do_delete(arg) {
	let name = clean_name(arg || '');
	let prof = PROFILES_DIR + '/' + name + '.yaml';
	if (!file_exists(prof)) return fail('Профиль не найден');
	if (current_active() == name) return fail('Нельзя удалить активную конфигурацию. Сначала примените другую.');
	let count = length(list_profiles());
	if (count <= 1) return fail('Нельзя удалить последнюю конфигурацию');
	system([ '/bin/rm', '-f', prof ]);
	let rows = [];
	let table = read_table(STATE_FILE);
	for (let i = 0; i < length(table); i++) {
		let r0 = table[i];
		if (r0[0] != name) push(rows, r0);
	}
	write_table(STATE_FILE, rows);
	if (current_active() == name) {
		unlink(ACTIVE_FILE);
	}
	return ok();
}

function do_rename_profile(old, new_name) {
	old = clean_name(old); new_name = clean_name(new_name);
	if (!valid_name(new_name)) return fail('Недопустимое новое имя');
	if (old == new_name) return ok();
	let oldp = PROFILES_DIR + '/' + old + '.yaml';
	let newp = PROFILES_DIR + '/' + new_name + '.yaml';
	if (!file_exists(oldp)) return fail('Профиль не найден');
	if (file_exists(newp)) return fail('Профиль с таким именем уже существует');
	system([ '/bin/mv', oldp, newp ]);
	let rows = [];
	let table = read_table(STATE_FILE);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r[0] == old) r[0] = new_name;
		push(rows, r);
	}
	write_table(STATE_FILE, rows);
	if (current_active() == old) write_file(ACTIVE_FILE, new_name + '\n');
	let state_files = [ TIME_FILE, TRIGGER_FILE ];
	for (let fi = 0; fi < length(state_files); fi++) {
		let f = state_files[fi];
		let rows2 = [];
		let table2 = read_table(f);
		for (let ri = 0; ri < length(table2); ri++) {
			let r = table2[ri];
			for (let i = 0; i < length(r); i++)
				if (r[i] == old) r[i] = new_name;
			push(rows2, r);
		}
		write_table(f, rows2);
	}
	if (read_file(DEFAULT_FILE) != null && read_file(DEFAULT_FILE) == old)
		write_file(DEFAULT_FILE, new_name + '\n');
	return ok();
}

function do_rule_import(req) {
	let name = clean_name(req.args.name || '');
	if (!valid_name(name)) return fail('Недопустимое имя файла');
	let ext = (req.args.ext == 'txt' || req.args.ext == '.txt') ? 'txt' : 'yaml';
	let interval = req.args.interval || '';
	if (!valid_interval(interval)) return fail('Недопустимое имя файла');
	if (interval != '' && interval != '0' && (int(interval) < 1 || int(interval) > 8760))
		return fail('Интервал от 1 до 8760 часов');
	if (req.args.url == '' && req.args.content == '')
		return fail('Укажите ссылку или содержимое файла');
	let tmp = '/tmp/rule-import-' + time();
	if (req.args.url != '') {
		if (!download_to(req.args.url, tmp)) { unlink(tmp); return fail('Не удалось скачать по ссылке'); }
	} else {
		write_file(tmp, req.args.content);
	}
	if (read_file(tmp) == null) { unlink(tmp); return fail('Пустой ответ по ссылке'); }
	let prof = RULES_DIR + '/' + name + '.' + ext;
	mkdir_p(RULES_DIR);
	system([ '/bin/mv', tmp, prof ]);
	state_update(RULES_STATE, name + '.' + ext, req.args.url || '', interval, '');
	return ok();
}

function do_rule_rename(req) {
	let old = req.args.old || '';
	let new_name = clean_name(req.args['new'] || '');
	let ext = req.args.ext || '.yaml';
	let old_prof = RULES_DIR + '/' + old;
	let new_prof = RULES_DIR + '/' + new_name + '.' + ext;
	if (read_file(old_prof) == null) return fail('Файл не найден');
	if (old_prof == new_prof) return ok();
	if (file_exists(new_prof)) return fail('Файл с таким именем уже существует');
	system([ '/bin/mv', old_prof, new_prof ]);
	let rows = [];
	let table = read_table(RULES_STATE);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r[0] == old) r[0] = new_name + '.' + ext;
		push(rows, r);
	}
	write_table(RULES_STATE, rows);
	return ok();
}

function do_rule_delete(name) {
	let prof = RULES_DIR + '/' + name;
	if (read_file(prof) == null) return fail('Файл не найден');
	unlink(prof);
	let rows = [];
	let table = read_table(RULES_STATE);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r[0] != name) push(rows, r);
	}
	write_table(RULES_STATE, rows);
	return ok();
}

function do_refresh(req) {
	let type = req.args.type || '';
	let name = clean_name(req.args.name || '');
	if (type != 'config' && type != 'rules') return fail('Неизвестный тип');
	let st = (type == 'config') ? STATE_FILE : RULES_STATE;
	let prof = (type == 'config') ? (PROFILES_DIR + '/' + name + '.yaml') : (RULES_DIR + '/' + name);
	if (read_file(prof) == null) return fail((type == 'config') ? 'Профиль не найден' : 'Файл не найден');
	let row = lookup_row(st, name);
	if (row == null) return fail('Источник не найден');
	let url = (row[1] == null) ? '' : row[1];
	if (url == '') return fail('У источника нет ссылки');
	let tmp = '/tmp/refresh-' + time();
	if (!download_to(url, tmp)) { unlink(tmp); return fail('Не удалось скачать по ссылке'); }
	if (read_file(tmp) == null) { unlink(tmp); return fail('Пустой ответ по ссылке'); }
	if (type == 'config') {
		let secs = (row[4] == null) ? '' : row[4];
		let content = read_file(tmp);
		unlink(tmp);
		let built = (secs != '') ? build_refresh_selected_config(content, read_file(prof), secs) : build_refresh_full_config(content, read_file(prof));
		if (built == null) return fail('Не удалось собрать конфигурацию');
		let b2 = '/tmp/refresh-build-' + time();
		write_file(b2, built);
		normalize_config(b2);
		let t = test_config(b2);
		if (!t.ok) { unlink(b2); return fail('Обновлённая конфигурация не прошла проверку Mihomo: ' + trim(t.output)); }
		unlink(prof);
		system([ '/bin/mv', b2, prof ]);
	} else {
		unlink(prof);
		system([ '/bin/mv', tmp, prof ]);
	}
	state_update(st, name, url, (row[2] == null) ? '' : row[2], (row[4] == null) ? '' : row[4]);
	return ok();
}

function do_normalize(req) {
	let path = req.args.path || '';
	if (path != MAIN_CONFIG && !(index(path, PROFILES_DIR + '/') == 0 && has_suffix(path, '.yaml')))
		return fail('Недопустимый путь конфигурации');
	normalize_config(path);
	return ok();
}

function do_set_interval(req) {
	let type = req.args.type || '';
	let name = clean_name(req.args.name || '');
	let st = (type == 'config') ? STATE_FILE : ((type == 'rules') ? RULES_STATE : '');
	if (st == '') return fail('Неизвестный тип');
	let interval = req.args.interval || '';
	if (!valid_interval(interval)) return fail('Некорректный интервал');
	if (interval != '' && interval != '0' && (int(interval) < 1 || int(interval) > 8760))
		return fail('Интервал от 1 до 8760 часов');
	let rows = [];
	let found = false;
	let table = read_table(st);
	for (let i = 0; i < length(table); i++) {
		let r0 = table[i];
		let r = r0;
		if (r[0] == name) { r[2] = (interval == '0') ? '' : interval; found = true; }
		push(rows, r);
	}
	if (!found) return fail('Источник не найден');
	write_table(st, rows);
	return ok();
}

function do_set_url(req) {
	let type = req.args.type || '';
	let name = clean_name(req.args.name || '');
	let url = req.args.url || '';
	let interval = req.args.interval || '';
	let st = (type == 'config') ? STATE_FILE : ((type == 'rules') ? RULES_STATE : '');
	if (st == '') return fail('Неизвестный тип');
	if (!valid_interval(interval)) return fail('Некорректный интервал');
	if (interval != '' && interval != '0' && (int(interval) < 1 || int(interval) > 8760))
		return fail('Интервал от 1 до 8760 часов');
	state_update(st, name, url, interval, null);
	return ok();
}

function do_schedule_list() {
	let time_rows = [];
	let time_table = read_table(TIME_FILE);
	for (let i = 0; i < length(time_table); i++) {
		let r = time_table[i];
		if (r != null && length(r) > 0 && r[0] != '')
			push(time_rows, schedule_time_row(r));
	}
	let trigger_rows = [];
	let trigger_table = read_table(TRIGGER_FILE);
	for (let i = 0; i < length(trigger_table); i++) {
		let r = trigger_table[i];
		if (r != null && length(r) > 0 && r[0] != '')
			push(trigger_rows, schedule_trigger_row(r));
	}
	return ok({
		'default': (read_file(DEFAULT_FILE) == null) ? '' : trim(read_file(DEFAULT_FILE)),
		time: time_rows,
		trigger: trigger_rows,
		timeOrder: order_read('sched_time'),
		triggerOrder: order_read('sched_trigger')
	});
}

function do_schedule_default(req) {
	let profile = clean_name(req.args.profile || '');
	mkdir_p(SCHED_DIR);
	write_file(DEFAULT_FILE, profile + '\n');
	return ok();
}

function schedule_time_row(r) {
	return {
		name: r[0],
		enabled: (r[1] == '1') ? 1 : 0,
		profile: (r[2] == null) ? '' : r[2],
		start: (r[3] == null) ? '' : r[3],
		end: (r[4] == null) ? '' : r[4],
		days: (r[5] == null || r[5] == '') ? 'all' : r[5],
		dom: (r[6] == null || r[6] == '') ? 'all' : r[6],
		months: (r[7] == null || r[7] == '') ? 'all' : r[7]
	};
}

function schedule_trigger_row(r) {
	return {
		name: r[0],
		enabled: (r[1] == '1') ? 1 : 0,
		urls: (r[2] == null) ? '' : r[2],
		interval: (r[3] == null || r[3] == '') ? '5' : r[3],
		fallback: (r[4] == null) ? '' : r[4],
		primary: (r[5] == null) ? '' : r[5],
		threshold: (r[6] == null || r[6] == '') ? '2' : r[6]
	};
}

function do_schedule_delete(req) {
	let type = req.args.type || '';
	let name = clean_name(req.args.name || '');
	let st = (type == 'time') ? TIME_FILE : ((type == 'trigger') ? TRIGGER_FILE : '');
	if (st == '') return fail('Неизвестный тип расписания');
	let rows = [];
	let table = read_table(st);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r[0] != name) push(rows, r);
	}
	write_table(st, rows);
	system([ '/bin/rm', '-f', SCHED_DIR + '/.last_' + name, SCHED_DIR + '/.fails_' + name ]);
	return ok();
}

function do_schedule_set_enabled(req) {
	let type = req.args.type || '';
	let name = clean_name(req.args.name || '');
	let st = (type == 'time') ? TIME_FILE : ((type == 'trigger') ? TRIGGER_FILE : '');
	if (st == '') return fail('Неизвестный тип расписания');
	let rows = [];
	let found = false;
	let table = read_table(st);
	for (let i = 0; i < length(table); i++) {
		let r0 = table[i];
		let r = r0;
		if (r[0] == name) { r[1] = req.args.enabled ? '1' : '0'; found = true; }
		push(rows, r);
	}
	if (!found) return fail('Расписание не найдено');
	write_table(st, rows);
	return ok();
}

function do_schedule_save(req) {
	let type = req.args.type || '';
	let name = clean_name(req.args.name || '');
	if (name == '') return fail('Недопустимое имя расписания');
	if (type != 'time' && type != 'trigger') return fail('Неизвестный тип расписания');
	mkdir_p(SCHED_DIR);
	let enabled = !!req.args.enabled;

	if (type == 'time') {
		let profile = clean_name(req.args.profile || '');
		let start = req.args.start || '';
		let end = req.args.end || '';
		if (start != '' && match(start, /^[0-9]{2}:[0-9]{2}$/) == null) return fail('Некорректное время начала');
		if (end != '' && match(end, /^[0-9]{2}:[0-9]{2}$/) == null) return fail('Некорректное время окончания');
		if (profile == '') return fail('Выберите профиль');
		let days = normalize_days(req.args.days);
		let dom = normalize_range(req.args.dom, 1, 31, 'Недопустимое число месяца');
		let months = normalize_range(req.args.months, 1, 12, 'Некорректный месяц');
		if (enabled && (start != '' || end != '')) {
			let conflict = find_time_conflict(name, start, end, days, dom, months);
			if (conflict != '')
				return fail('Слот занят: расписание «' + conflict + '»');
		}
		let rows = [];
		let found = false;
		let table = read_table(TIME_FILE);
		for (let i = 0; i < length(table); i++) {
			let r = table[i];
			if (r[0] == name) {
				r[1] = enabled ? '1' : '0';
				r[2] = profile; r[3] = start; r[4] = end; r[5] = days; r[6] = dom; r[7] = months;
				found = true;
			}
			push(rows, r);
		}
		if (!found)
			push(rows, [ name, enabled ? '1' : '0', profile, start, end, days, dom, months ]);
		write_table(TIME_FILE, rows);
		return ok();
	}

	let urls = req.args.urls || '';
	if (urls == '') return fail('Укажите хотя бы один URL');
	let interval = req.args.interval || '5';
	if (!is_digit(interval)) interval = '5';
	let threshold = req.args.threshold || '2';
	if (!is_digit(threshold)) threshold = '2';
	let rows = [];
	let found = false;
	let table = read_table(TRIGGER_FILE);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r[0] == name) {
			r[1] = enabled ? '1' : '0';
			r[2] = urls; r[3] = interval; r[4] = req.args.fallback || ''; r[5] = req.args.primary || ''; r[6] = threshold;
			found = true;
		}
		push(rows, r);
	}
	if (!found)
		push(rows, [ name, enabled ? '1' : '0', urls, interval, req.args.fallback || '', req.args.primary || '', threshold ]);
	write_table(TRIGGER_FILE, rows);
	return ok();
}

function normalize_days(s) {
	if (s == null || s == '' || s == 'all' || s == '-') return 'all';
	let out = [];
	let parts = split(s, ',');
	for (let j = 0; j < length(parts); j++) {
		let d = parts[j];
		if (is_digit(d)) {
			let i = int(d);
			if (i >= 0 && i <= 6) push(out, '' + i);
		}
	}
	return (length(out) == 0) ? 'all' : join(',', out);
}

function normalize_range(s, min, max, msg) {
	if (s == null || s == '' || s == 'all' || s == '-') return 'all';
	let out = [];
	let parts = split(s, ',');
	for (let j = 0; j < length(parts); j++) {
		let d = parts[j];
		if (is_digit(d)) {
			let i = int(d);
			if (i >= min && i <= max) push(out, '' + i);
		}
	}
	return (length(out) == 0) ? 'all' : join(',', out);
}

function list_contains(list1, v) {
	if (list1 == '' || list1 == 'all' || list1 == '-') return true;
	return index(',' + list1 + ',', ',' + v + ',') >= 0;
}

function to_min(t) {
	if (t == null || t == '') return -1;
	let p = split(t, ':');
	return int(p[0]) * 60 + int(p[1]);
}

function windows_overlap(x1, y1, x2, y2) {
	let a1 = (x1 == '') ? 0 : to_min(x1);
	let b1 = (y1 == '') ? 1440 : to_min(y1);
	let a2 = (x2 == '') ? 0 : to_min(x2);
	let b2 = (y2 == '') ? 1440 : to_min(y2);
	if (a1 == b1) b1++;
	if (a2 == b2) b2++;
	let s1 = (a1 < b1) ? [ a1, b1 ] : [ a1, 1440, 0, b1 ];
	let s2 = (a2 < b2) ? [ a2, b2 ] : [ a2, 1440, 0, b2 ];
	/* check pairwise */
	for (let i = 0; i < length(s1); i += 2) {
		for (let j = 0; j < length(s2); j += 2) {
			if (s1[i] < s2[j + 1] && s2[j] < s1[i + 1])
				return true;
		}
	}
	return false;
}

function day_matches(mon1, wday1, dom1, days, doms, months) {
	if (!list_contains(months, mon1)) return false;
	let da = (days == '' || days == 'all' || days == '-');
	let dma = (doms == '' || doms == 'all' || doms == '-');
	if (da && dma) return true;
	if (!da && list_contains(days, wday1)) return true;
	if (!dma && list_contains(doms, dom1)) return true;
	return false;
}

function find_time_conflict(self_name, start, end, days, dom, months) {
	let now = time();
	let table = read_table(TIME_FILE);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r == null || r[0] == '' || r[0] == self_name) continue;
		if (r[1] != '1') continue;
		let s2 = (r[3] == null) ? '' : r[3];
		let e2 = (r[4] == null) ? '' : r[4];
		if (!windows_overlap(start, end, s2, e2)) continue;
		let days2 = (r[5] == null) ? 'all' : r[5];
		let dom2 = (r[6] == null) ? 'all' : r[6];
		let months2 = (r[7] == null) ? 'all' : r[7];
		for (let i = 0; i < 366; i++) {
			let day = localtime(now + i * 86400);
			let mon1 = '' + day.mon;
			let wday1 = '' + day.wday;
			let domv = '' + day.mday;
			if (day_matches(mon1, wday1, domv, days, dom, months) && day_matches(mon1, wday1, domv, days2, dom2, months2))
				return r[0];
		}
	}
	return '';
}

function subscription_value(content, key) {
	let lines = split(content || '', '\n');
	for (let i = 0; i < length(lines); i++) {
		let p = index(lines[i], '=');
		if (p > 0 && substr(lines[i], 0, p) == key) return substr(lines[i], p + 1);
	}
	return '';
}

function subscription_id(value) {
	let id = clean_name(value || '');
	return (id == '') ? '' : id;
}

function subscription_defaults() {
	let version = read_file('/etc/mixomo/versions/mihomo') || '';
	let release = read_file('/etc/openwrt_release') || '';
	let model = read_file('/tmp/sysinfo/model') || '';
	let m = match(release, /DISTRIB_RELEASE='([^']+)'/);
	return {
		mihomo_version: trim(version),
		hwid: 'Router',
		device_os: 'OpenWrt',
		openwrt_version: m == null ? '' : m[1],
		router_model: trim(model)
	};
}

function subscription_headers(req) {
	let d = subscription_defaults();
	if (!req.args.manual) return [ d.mihomo_version, d.hwid, d.device_os, d.openwrt_version, d.router_model ];
	return [
		req.args.mihomo_version || d.mihomo_version,
		req.args.hwid || d.hwid,
		req.args.device_os || d.device_os,
		req.args.openwrt_version || d.openwrt_version,
		req.args.router_model || d.router_model
	];
}

function save_subscription(req) {
	with_defaults(req.args, [ 'id', 'name', 'url', 'interval', 'mihomo_version', 'hwid', 'device_os', 'openwrt_version', 'router_model' ]);
	if (req.args.manual == null) req.args.manual = false;
	let id = subscription_id(req.args.id || req.args.name || '');
	let url = req.args.url || '';
	let interval = req.args.interval || '';
	if (interval == '') return fail('Недопустимый интервал provider ' + id + ': пустое значение');
	if (!valid_name(id) || id == '') return fail('Недопустимое имя provider ' + id);
	if (url == '' || (index(url, 'http://') != 0 && index(url, 'https://') != 0 && index(url, 'happ://') != 0) || match(url, /[\r\n]/) != null) return fail('Недопустимая ссылка provider ' + id);
	if (!valid_interval(interval)) return fail('Недопустимый интервал provider ' + id + ': ' + interval);
	mkdir_p(SUBSCRIPTION_PROVIDERS_DIR);
	let h = subscription_headers(req);
	for (let hi = 0; hi < length(h); hi++) if (match(h[hi] || '', /[\r\n]/) != null) return fail('Недопустимый header');
	let data = 'id=' + id + '\nurl=' + url + '\ninterval=' + interval + '\nmanual=' + (req.args.manual ? '1' : '0') + '\nmihomo_version=' + h[0] + '\nhwid=' + h[1] + '\ndevice_os=' + h[2] + '\nopenwrt_version=' + h[3] + '\nrouter_model=' + h[4] + '\n';
	if (!write_file(SUBSCRIPTION_PROVIDERS_DIR + '/' + id, data)) return fail('Не удалось записать provider-файл ' + id);
	if (!write_file(SUBSCRIPTIONS_DIR + '/' + id + '.url', url + '\n')) return fail('Не удалось записать metadata provider ' + id);
	return ok({ id: id });
}

function list_subscriptions() {
	let out = [];
	let defaults = subscription_defaults();
	let files = list_dir(SUBSCRIPTION_PROVIDERS_DIR + '/');
	for (let i = 0; i < length(files); i++) {
		let content = read_file(SUBSCRIPTION_PROVIDERS_DIR + '/' + files[i]);
		if (content == null) continue;
		push(out, {
			id: subscription_value(content, 'id'), url: subscription_value(content, 'url'),
			interval: subscription_value(content, 'interval'), manual: subscription_value(content, 'manual') == '1',
			mihomo_version: subscription_value(content, 'mihomo_version') || defaults.mihomo_version,
			hwid: subscription_value(content, 'hwid') || defaults.hwid,
			device_os: subscription_value(content, 'device_os') || defaults.device_os,
			openwrt_version: subscription_value(content, 'openwrt_version') || defaults.openwrt_version,
			router_model: subscription_value(content, 'router_model') || defaults.router_model,
		});
	}
	return ok({ providers: out, defaults: defaults });
}

function delete_subscription(req) {
	with_defaults(req.args, [ 'id' ]);
	let id = subscription_id(req.args.id || '');
	if (id == '') return fail('Недопустимый provider');
	unlink(SUBSCRIPTION_PROVIDERS_DIR + '/' + id);
	unlink(SUBSCRIPTIONS_DIR + '/' + id + '.url');
	unlink('/etc/mihomo/proxy-providers/' + id + '.txt');
	unlink('/etc/mihomo/proxy-providers/' + id + '.yaml');
	return ok();
}

function json_escape(value) {
	value = value || '';
	value = replace(value, '\\', '\\\\');
	value = replace(value, '"', '\\"');
	value = replace(value, '\r', '\\r');
	value = replace(value, '\n', '\\n');
	return value;
}

function happy_unescape(value) {
	value = replace(value || '', '\\\\u0026', '&');
	value = replace(value, '\\\\/', '/');
	value = replace(value, '\\\\"', '"');
	value = replace(value, '\\\\n', '\n');
	value = replace(value, '\\\\r', '\r');
	value = replace(value, '\\\\t', '\t');
	value = replace(value, '\\\\', '\\');
	return value;
}

function happy_response_value(content, key) {
	content = content || '';
	let needle = '"' + key + '"';
	let pos = index(content, needle);
	while (pos >= 0) {
		let rest = substr(content, pos + length(needle));
		let colon = index(rest, ':');
		if (colon < 0) return '';
		rest = substr(rest, colon + 1);
		let start = index(rest, '"');
		if (start < 0) return '';
		rest = substr(rest, start + 1);
		let out = '';
		let i = 0;
		while (i < length(rest)) {
			let ch = substr(rest, i, 1);
			if (ch == '\\' && i + 1 < length(rest)) {
				out += substr(rest, i, 2);
				i += 2;
				continue;
			}
			if (ch == '"') return happy_unescape(out);
			out += ch;
			i++;
		}
		return '';
	}
	return '';
}

function happy_key_status() { return ok({ configured: file_exists(HAPPY_KEY_FILE) && trim(read_file(HAPPY_KEY_FILE) || '') != '' }); }

function happy_key_generate() {
	mkdir_p('/etc/mixomo/secrets');
	let out = secure_temp('mixomo-happy-key');
	if (out == '') return fail('Не удалось создать временный файл');
	if (system([ '/usr/bin/curl', '-fsS', '--connect-timeout', '10', '--max-time', '30', '-X', 'POST', 'https://happy-decoder.cc/api/v1/keys', '-o', out ]) != 0) { unlink(out); return fail('Не удалось сгенерировать API key'); }
	let key_response = read_file(out);
	let key = happy_response_value(key_response, 'key');
	if (key == '') key = happy_response_value(key_response, 'api_key');
	unlink(out);
	if (key == '') return fail('Сервис не вернул API key');
	if (!write_file(HAPPY_KEY_FILE, key + '\n')) return fail('Не удалось сохранить API key');
	system([ '/bin/chmod', '600', HAPPY_KEY_FILE ]);
	return ok({ configured: true });
}

function happy_decrypt(req) {
	with_defaults(req.args, [ 'url' ]);
	let url = req.args.url || '';
	if (index(url, 'happ://crypt') != 0) return ok({ url: url });
	let key = trim(read_file(HAPPY_KEY_FILE) || '');
	if (key == '') return fail('API key не настроен');
	let body = secure_temp('mixomo-happy-body');
	let out = secure_temp('mixomo-happy-response');
	let cfg = secure_temp('mixomo-happy-curl');
	if (body == '' || out == '' || cfg == '') { if (body != '') unlink(body); if (out != '') unlink(out); if (cfg != '') unlink(cfg); return fail('Не удалось создать временные файлы'); }
	let payload = '{"url":"' + json_escape(url) + '"}';
	write_file(body, payload);
	write_file(cfg, 'silent\nshow-error\nfail\nconnect-timeout = 10\nmax-time = 30\nrequest = POST\nurl = "https://happy-decoder.cc/api/v1/decrypt"\nheader = "Authorization: Bearer ' + key + '"\nheader = "Content-Type: application/json"\ndata = @' + body + '\noutput = ' + out + '\n');
	system([ '/bin/chmod', '600', body, cfg, out ]);
	let rc = system([ '/usr/bin/curl', '-K', cfg ]);
	let response = read_file(out);
	unlink(body); unlink(cfg); unlink(out);
	if (rc != 0) return fail('Не удалось расшифровать ссылку');
	let decoded = happy_response_value(response, 'decryptedUrl');
	if (decoded == '') decoded = happy_response_value(response, 'url');
	if (decoded == '') decoded = happy_response_value(response, 'subscription_url');
	if (decoded == '') decoded = happy_response_value(response, 'decoded_url');
	if (decoded == '') return fail('Сервис не вернул ссылку');
	return ok({ url: decoded });
}

function yaml_quote(value) {
	value = value || '';
	value = replace(value, '\r', ' ');
	value = replace(value, '\n', ' ');
	value = replace(value, "'", "''");
	return "'" + value + "'";
}

const SUBSCRIPTION_COMPACT_KEYS = [ 'external-controller', 'external-ui', 'external-ui-url', 'mixed-port', 'redir-port', 'allow-lan', 'mode', 'ipv6', 'log-level', 'unified-delay', 'tcp-concurrent', 'find-process-mode', 'routing-mark', 'profile', 'sniffer' ];

function subscription_top_key(line) {
	let m = match(line || '', /^([A-Za-z_][A-Za-z0-9_-]*):/);
	return (m == null) ? '' : m[1];
}

function subscription_format(content) {
	let lines = split(content || '', '\n');
	let out = [];
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		let key = subscription_top_key(line);
		if (key == '') { push(out, line); continue; }
		while (length(out) > 0 && out[length(out) - 1] == '') out = slice(out, 0, length(out) - 1);
		if (index(SUBSCRIPTION_COMPACT_KEYS, key) < 0 && length(out) > 0) push(out, '');
		push(out, line);
		let j = i + 1;
		while (j < length(lines) && lines[j] == '') j++;
		i = j - 1;
	}
	return join('\n', out);
}

function subscription_format_profile(path) {
	let content = read_file(path);
	if (content == null) return false;
	let formatted = subscription_format(content);
	if (formatted == content) return true;
	return write_file(path, formatted);
}

function subscription_content(providers) {
	if (!providers || !length(providers)) return fail('Добавьте хотя бы один provider');
	let needs_happy_key = false;
	for (let pi = 0; pi < length(providers); pi++) if (index(providers[pi].url || '', 'happ://crypt') == 0) needs_happy_key = true;
	if (needs_happy_key && trim(read_file(HAPPY_KEY_FILE) || '') == '') {
		let key_result = happy_key_generate();
		if (!key_result.ok) return fail('Этап API key: ' + (key_result.error || 'неизвестная ошибка'));
	}
	let provider_yaml = '', uses = '';
	for (let i = 0; i < length(providers); i++) {
		let p = providers[i];
		let id = subscription_id(p.id || '');
		let url = p.url || '';
		let interval = p.interval || '';
		if (!valid_name(id) || id == '') return fail('Недопустимое имя provider ' + id);
		if (url == '' || (index(url, 'http://') != 0 && index(url, 'https://') != 0 && index(url, 'happ://') != 0) || match(url, /[\r\n]/) != null) return fail('Недопустимая ссылка provider ' + id);
		if (!valid_interval(interval)) return fail('Недопустимый интервал provider ' + id + ': ' + interval);
		for (let hi = 0; hi < 5; hi++) if (match(p[[ 'mihomo_version', 'hwid', 'device_os', 'openwrt_version', 'router_model' ][hi]] || '', /[\r\n]/) != null) return fail('Недопустимый header');
		let resolved = happy_decrypt({ args: { url: url } });
		if (!resolved.ok) return fail('Не удалось расшифровать provider ' + id + ': ' + resolved.error);
		let interval_seconds = (interval == '0') ? 0 : int(interval || '0') * 3600;
		if (interval_seconds == null || interval_seconds < 0) return fail('Недопустимый интервал provider ' + id);
		if (provider_yaml != '') provider_yaml += '\n';
		provider_yaml += '  ' + id + ':\n    type: http\n    proxy: DIRECT\n    path: ./proxy-providers/' + id + '.txt\n    header:\n      User-Agent: [' + yaml_quote('mihomo/' + p.mihomo_version) + ']\n      x-hwid: [' + yaml_quote(p.hwid) + ']\n      x-device-os: [' + yaml_quote(p.device_os) + ']\n      x-ver-os: [' + yaml_quote(p.openwrt_version) + ']\n      x-device-model: [' + yaml_quote(p.router_model) + ']\n    url: ' + yaml_quote(resolved.url) + '\n    interval: ' + interval_seconds + '\n    override:\n      udp: true\n    health-check:\n      enable: true\n      url: https://www.google.com/generate_204\n      interval: 300\n      timeout: 500\n      lazy: true\n';
		uses += '      - ' + id + '\n';
	}
	let groups = '  - name: "YouTube"\n    type: fallback\n    url: http://gstatic.com/generate_204\n    expected-status: 204\n    interval: 300\n    lazy: true\n    proxies:\n      - Домашний интернет\n      - Прокси\n    use:\n' + uses +
		'\n  - name: "Интернет"\n    type: fallback\n    url: http://gstatic.com/generate_204\n    expected-status: 204\n    interval: 300\n    lazy: true\n    proxies:\n      - Прокси без России\n      - Прокси\n    use:\n' + uses +
		'\n  - name: "Прокси без России"\n    type: url-test\n    url: https://google.com/generate_204\n    expected-status: 204\n    interval: 300\n    timeout: 500\n    lazy: true\n    use:\n' + uses +
		'    exclude-filter: "Russia|Russian|Россия|РФ|Российский|🇷🇺"\n' +
		'\n  - name: "Прокси"\n    type: url-test\n    url: https://google.com/generate_204\n    expected-status: 204\n    interval: 300\n    timeout: 500\n    lazy: true\n    use:\n' + uses;
	let template = read_file(SUBSCRIPTION_TEMPLATE);
	if (template == null) return fail('Шаблон профиля не найден');
	return ok({ content: replace(replace(template, '__PROXY_PROVIDERS__', provider_yaml), '__PROXY_GROUPS__', groups) });
}

function subscription_state_rename(old_name, name) {
	if (old_name == name) { state_update(STATE_FILE, name, '', '', '', 'subscription'); return; }
	let rows = [], table = read_table(STATE_FILE);
	for (let i = 0; i < length(table); i++) {
		let row = table[i];
		if (row[0] == old_name) row[0] = name;
		push(rows, row);
	}
	write_table(STATE_FILE, rows);
	state_update(STATE_FILE, name, '', '', '', 'subscription');
}

function subscription_replace(req) {
	let old_name = clean_name(req.args.old || '');
	let name = clean_name(req.args.name || '');
	if (!valid_name(name) || (old_name != '' && !valid_name(old_name))) return fail('Недопустимое имя профиля');
	let old_profile = PROFILES_DIR + '/' + old_name + '.yaml';
	let profile = PROFILES_DIR + '/' + name + '.yaml';
	if (old_name != '' && !file_exists(old_profile)) return fail('Профиль не найден');
	if (old_name != name && file_exists(profile)) return fail('Профиль с таким именем уже существует');
	let listed = list_subscriptions();
	if (!listed.ok) return fail('Не удалось прочитать providers: ' + (listed.error || 'неизвестная ошибка'));
	let built = subscription_content(listed.providers || []);
	if (!built.ok) return built;
	let tmp = secure_temp('mixomo-subscription');
	if (tmp == '') return fail('Не удалось создать временный файл');
	if (!write_file(tmp, built.content)) { unlink(tmp); return fail('Не удалось сохранить временную конфигурацию'); }
	normalize_config(tmp);
	let checked = test_config(tmp);
	if (!checked.ok) { unlink(tmp); return fail('Конфигурация не прошла проверку Mihomo: ' + trim(checked.output)); }
	if (system([ '/bin/mv', tmp, profile ]) != 0) { unlink(tmp); return fail('Не удалось заменить профиль'); }
	let current_ids = [];
	for (let ci = 0; ci < length(listed.providers || []); ci++) push(current_ids, subscription_id((listed.providers || [])[ci].id || ''));
	let cached = list_dir('/etc/mihomo/proxy-providers/');
	for (let cfi = 0; cfi < length(cached); cfi++) {
		let cache_name = cached[cfi];
		let cache_id = cache_name;
		if (has_suffix(cache_id, '.txt')) cache_id = substr(cache_id, 0, length(cache_id) - 4);
		else if (has_suffix(cache_id, '.yaml')) cache_id = substr(cache_id, 0, length(cache_id) - 5);
		else continue;
		if (index(current_ids, cache_id) < 0) unlink('/etc/mihomo/proxy-providers/' + cache_name);
	}
	if (old_name != '' && old_name != name) {
		unlink(old_profile);
		subscription_state_rename(old_name, name);
		if (current_active() == old_name) write_file(ACTIVE_FILE, name + '\n');
	} else {
		state_update(STATE_FILE, name, '', '', '', 'subscription');
	}
	subscription_format_profile(profile);
	return ok();
}

function generate_subscription_profile(req) {
	let listed = list_subscriptions();
	if (!listed.ok) return fail('Не удалось прочитать providers: ' + (listed.error || 'неизвестная ошибка'));
	let built = subscription_content(listed.providers || []);
	if (!built.ok) return built;
	let name = clean_name(req.args.name || '');
	if (!valid_name(name)) return fail('Недопустимое имя профиля');
	let created = do_import_full({ args: { name: name, url: '', content: built.content } });
	if (!created.ok) return created;
	state_update(STATE_FILE, name, '', '', '', 'subscription');
	subscription_format_profile(PROFILES_DIR + '/' + name + '.yaml');
	return ok();
}

const methods = {
	list: { call: emit_list },
	apply: { args: { name: 'string', panel: 'string' }, call: function(req) { return apply_profile(req.args.name || '', req.args.panel || ''); } },
	set_dashboard: { args: { panel: 'string' }, call: function(req) { return set_dashboard_panel(req.args.panel || ''); } },
	normalize: { args: { path: 'string' }, call: do_normalize },
	'import': {
		args: { name: 'string', url: 'string', content: 'string', sections: 'string', interval: 'string' },
		call: do_import
	},
	import_full: { args: { name: 'string', url: 'string', content: 'string' }, call: do_import_full },
	create: { args: { name: 'string', copyActive: true }, call: do_create },
	'delete': { args: { name: 'string' }, call: function(req) { return do_delete(req.args.name || ''); } },
	rename_profile: {
		args: { old: 'string', 'new': 'string' },
		call: function(req) { return do_rename_profile(req.args.old || '', req.args['new'] || ''); }
	},
	rule_import: {
		args: { name: 'string', url: 'string', content: 'string', ext: 'string', interval: 'string' },
		call: do_rule_import
	},
	rule_rename: { args: { old: 'string', 'new': 'string', ext: 'string' }, call: do_rule_rename },
	rule_delete: { args: { name: 'string' }, call: function(req) { return do_rule_delete(req.args.name || ''); } },
	refresh: { args: { type: 'string', name: 'string' }, call: do_refresh },
	set_interval: { args: { type: 'string', name: 'string', interval: 'string' }, call: do_set_interval },
	set_url: { args: { type: 'string', name: 'string', url: 'string', interval: 'string' }, call: do_set_url },
	set_order: { args: { list: 'string', names: 'string' }, call: function(req) {
		if (index([ 'configs', 'rules', 'sched_time', 'sched_trigger' ], req.args.list || '') < 0)
			return fail('Неизвестный список');
		return order_write(req.args.list, req.args.names || '');
	} },
	schedule_list: { call: do_schedule_list },
	schedule_default: { args: { profile: 'string' }, call: do_schedule_default },
	schedule_save: {
		args: { type: 'string', name: 'string', enabled: true, profile: 'string', start: 'string', end: 'string', days: 'string', dom: 'string', months: 'string', urls: 'string', interval: 'string', fallback: 'string', primary: 'string', threshold: 'string' },
		call: do_schedule_save
	},
	schedule_delete: { args: { type: 'string', name: 'string' }, call: do_schedule_delete },
	schedule_set_enabled: { args: { type: 'string', name: 'string', enabled: true }, call: do_schedule_set_enabled },
	subscription_list: { call: list_subscriptions },
		subscription_add: { args: { id: 'string', url: 'string', interval: 'string', manual: true, mihomo_version: 'string', hwid: 'string', device_os: 'string', openwrt_version: 'string', router_model: 'string' }, call: save_subscription },
	subscription_update: { args: { id: 'string', url: 'string', interval: 'string', manual: true, mihomo_version: 'string', hwid: 'string', device_os: 'string', openwrt_version: 'string', router_model: 'string' }, call: save_subscription },
	subscription_delete: { args: { id: 'string' }, call: delete_subscription },
	subscription_generate: { args: { name: 'string' }, call: generate_subscription_profile },
	subscription_replace: { args: { old: 'string', name: 'string' }, call: subscription_replace },
	happy_key_status: { call: happy_key_status },
	happy_key_generate: { call: happy_key_generate },
	happy_decrypt: { args: { url: 'string' }, call: happy_decrypt }
};

export { methods };