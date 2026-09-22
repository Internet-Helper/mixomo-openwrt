'use strict';

/*
 * Mixomo shared library for ucode RPC backends and the schedule daemon.
 * Installed at /usr/share/ucode/mixomo.uc
 * Import with:  import { fn } from 'mixomo';
 */

import { readfile, writefile, access, popen } from 'fs';

const MIXOMO_PROFILES = '/etc/mixomo/profiles';
const STATE_FILE   = MIXOMO_PROFILES + '/state';
const ACTIVE_FILE   = MIXOMO_PROFILES + '/active';
const PROFILES_DIR = '/etc/mihomo/profiles';
const RULES_DIR    = '/etc/mihomo/rule-files';
const RULES_STATE  = MIXOMO_PROFILES + '/rules-state';
const MAIN_CONFIG  = '/etc/mihomo/config.yaml';
const DEFAULT_CONFIG = '/etc/mihomo/config.template.yaml';
const MIHOMO_BIN   = '/usr/bin/mihomo';
const API_URL      = 'http://127.0.0.1:9090';
const SCHED_DIR    = '/etc/mixomo/schedule';
const TIME_FILE    = SCHED_DIR + '/time';
const TRIGGER_FILE = SCHED_DIR + '/trigger';
const DEFAULT_FILE = SCHED_DIR + '/default';

function read_file(path) {
	let s = readfile(path);
	return (s == null) ? null : s;
}

function write_file(path, data) {
	return writefile(path, data) != null;
}

function mkdir_p(path) {
	return system([ '/bin/mkdir', '-p', path ]);
}

function file_exists(path) {
	return access(path, 'f');
}

function dirname_strip(path) {
	let i = rindex(path, '/');
	return (i < 0) ? '.' : substr(path, 0, i);
}

function clean_name(name) {
	return replace(name || '', /[^A-Za-z0-9._-]/g, '');
}

function valid_name(s) {
	if (s == null || s == '') return false;
	if (s == '.' || s == '..' || index(s, '..') >= 0) return false;
	return length(s) <= 64;
}

function download_to(url, out) {
	if (access('/usr/bin/curl', 'x') || access('/usr/sbin/curl', 'x'))
		if (system([ '/usr/bin/curl', '-fsSL', '--connect-timeout', '10', '--max-time', '60', '-o', out, url ]) == 0)
			return true;
	if (access('/usr/bin/wget', 'x') || access('/usr/sbin/wget', 'x'))
		if (system([ '/usr/bin/wget', '-q', '-T', '60', '-O', out, url ]) == 0)
			return true;
	return false;
}

/* ---- tab-separated state files ---------------------------------------- */

function read_table(path) {
	let rows = [];
	let s = readfile(path);
	if (s == null) return rows;
	let lines = split(s, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (line != '')
			push(rows, split(line, '\t'));
	}
	return rows;
}

function write_table(path, rows) {
	mkdir_p(dirname_strip(path));
	let out = '';
	for (let i = 0; i < length(rows); i++)
		out += join('\t', rows[i]) + '\n';
	return writefile(path, out) != null;
}

function lookup_row(path, name) {
	let rows = read_table(path);
	for (let i = 0; i < length(rows); i++) {
		let row = rows[i];
		if (row[0] == name)
			return row;
	}
	return null;
}

function state_update(path, name, url, interval, secs, source) {
	let rows = [];
	let found = false;
	let table = read_table(path);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r[0] == name) {
			if (url != null) r[1] = url;
			if (interval != null) r[2] = interval;
			r[3] = ('' + time());
			if (secs != null) r[4] = secs;
			if (source != null) r[5] = source;
			found = true;
		}
		push(rows, r);
	}
	if (!found) {
		push(rows, [
			name,
			(url == null) ? '' : url,
			(interval == null) ? '' : interval,
			('' + time()),
			(secs == null) ? '' : secs,
			(source == null) ? '' : source
		]);
	}
	write_table(path, rows);
}

function state_touch(path, name) {
	let rows = [];
	let table = read_table(path);
	for (let i = 0; i < length(table); i++) {
		let r = table[i];
		if (r[0] == name) r[3] = ('' + time());
		push(rows, r);
	}
	write_table(path, rows);
}

/* ---- YAML section helpers ---------------------------------------- */

function section_key(line) {
	if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:/) == null) return null;
	return replace(line, /^([A-Za-z_][A-Za-z0-9_-]*):.*$/, '$1');
}

function extract_section(content, name) {
	if (content == null) return '';
	let out = [];
	let insec = false;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (line == '---' || line == '...') continue;
		let key = section_key(line);
		if (key != null) {
			if (key == name) { insec = true; push(out, line); continue; }
			if (insec) break;
			continue;
		}
		if (insec) push(out, line);
	}
	return join('\n', out);
}

function remove_section(content, name) {
	if (content == null) return content;
	let out = [];
	let skip = false;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		let key = section_key(line);
		if (key != null) {
			if (key == name) { skip = true; continue; }
			skip = false;
		}
		if (!skip) push(out, line);
	}
	return join('\n', out);
}

function extract_anchor_sections(content) {
	if (content == null) return '';
	let out = [];
	let insec = false;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:[ \t]*&[A-Za-z0-9_]/) != null) {
			insec = true; push(out, line); continue;
		}
		if (section_key(line) != null) { insec = false; continue; }
		if (insec) push(out, line);
	}
	return join('\n', out);
}

const MANAGED = [ 'proxies', 'proxy-groups', 'proxy-providers', 'rule-providers', 'rules' ];

function extract_external_anchor_sections(content) {
	if (content == null) return '';
	let out = [];
	let insec = false;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:[ \t]*&[A-Za-z0-9_]/) != null) {
			let key = replace(line, /^([A-Za-z_][A-Za-z0-9_-]*):.*$/, '$1');
			if (index(MANAGED, key) >= 0) { insec = false; continue; }
			insec = true;
			push(out, line);
			continue;
		}
		if (section_key(line) != null) { insec = false; continue; }
		if (insec) push(out, line);
	}
	return join('\n', out);
}

function prefix_before_proxies(content, stopper) {
	if (content == null) return '';
	let out = [];
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^proxies:/) != null) break;
		push(out, line);
	}
	return join('\n', out);
}

function from_proxies(content) {
	if (content == null) return '';
	let out = [];
	let insec = false;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^proxies:/) != null) insec = true;
		if (insec) push(out, line);
	}
	return join('\n', out);
}

function strip_trailing_blanks(s) {
	let lines = (s == null) ? [] : split(s, '\n');
	let end = length(lines);
	while (end > 0 && lines[end - 1] == '')
		end--;
	return join('\n', slice(lines, 0, end));
}

function strip_leading_blanks(s) {
	let lines = (s == null) ? [] : split(s, '\n');
	let start = 0;
	while (start < length(lines) && lines[start] == '')
		start++;
	return join('\n', slice(lines, start, length(lines)));
}

function append_block(current, content) {
	if (content == null || content == '') return current;
	if (current == null) current = '';
	current = strip_trailing_blanks(current);
	content = strip_leading_blanks(content);
	if (current != '') current += '\n\n';
	return current + content + '\n';
}

function valid_sections_list() { return MANAGED; }

function has_section(content, name) {
	let lines = split(content == null ? '' : content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^[A-Za-z_][A-Za-z0-9_-]*:/) != null && section_key(line) == name)
			return true;
	}
	return false;
}

function build_full_config(source) {
	let tpl = read_file(DEFAULT_CONFIG);
	if (tpl == null) return null;
	let out = prefix_before_proxies(tpl);
	out = append_block(out, extract_external_anchor_sections(source));
	out = append_block(out, from_proxies(has_section(source, 'proxies') ? source : tpl));
	out = strip_trailing_blanks(out);
	return out + '\n';
}

function build_selected_config(source, selected) {
	let tpl = read_file(DEFAULT_CONFIG);
	if (tpl == null) return null;
	let out = prefix_before_proxies(tpl);
	out = append_block(out, extract_external_anchor_sections(source));
	for (let i = 0; i < length(MANAGED); i++) {
		let section = MANAGED[i];
		let sec = (index(selected, section) >= 0) ? extract_section(source, section) : '';
		out = append_block(out, (sec != '') ? sec : (section + ':'));
	}
	out = strip_trailing_blanks(out);
	return out + '\n';
}

function build_refresh_full_config(source, existing) {
	let out = prefix_before_proxies(existing);
	out = append_block(out, from_proxies(has_section(source, 'proxies') ? source : existing));
	out = strip_trailing_blanks(out);
	return out + '\n';
}

function build_refresh_selected_config(source, existing, selected) {
	let out = existing;
	let selected_sections = split(selected, ',');
	for (let i = 0; i < length(selected_sections); i++)
		out = remove_section(out, selected_sections[i]);
	out = strip_trailing_blanks(out);
	selected_sections = split(selected, ',');
	for (let i = 0; i < length(selected_sections); i++) {
		let section = selected_sections[i];
		let sec = extract_section(source, section);
		out = append_block(out, (sec != '') ? sec : (section + ':'));
	}
	out = strip_trailing_blanks(out);
	return out + '\n';
}

/* ---- config / profile handling --------------------------------- */

function first_int_or(s, re, fallback) {
	let m = match(s, re);
	if (m == null) return fallback;
	return m[1];
}

function normalize_config(path) {
	let s = read_file(path);
	if (s == null) return false;

	let mixed = '7890';
	let mixed_found = false;
	let redir = '5001';
	let rf = read_file('/etc/mixomo/routing/redir-port');
	if (rf != null && trim(rf) != '' && match(trim(rf), /^[0-9]+$/) != null)
		redir = trim(rf);

	let lines = split(s, '\n');
	let normalized = [];
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^port:[ \t]*[0-9]/) != null) continue;
		if (match(line, /^socks-port:[ \t]*[0-9]/) != null) continue;
		let m = match(line, /^mixed-port:[ \t]*([0-9]+)/);
		if (m != null) {
			mixed = m[1];
			mixed_found = true;
			line = 'mixed-port: ' + mixed;
		}
		if (match(line, /^redir-port:/) != null)
			line = 'redir-port: ' + redir;
		push(normalized, line);
	}
	s = join('\n', normalized);
	if (!mixed_found) s = 'mixed-port: ' + mixed + '\n' + s;

	let redir_found = false;
	lines = split(s, '\n');
	let final_lines = [];
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^redir-port:/) != null) {
			line = 'redir-port: ' + redir;
			redir_found = true;
		}
		push(final_lines, line);
	}
	if (!redir_found) s = 'redir-port: ' + redir + '\n' + join('\n', final_lines);
	else s = join('\n', final_lines);

	writefile(path, s);
	return true;
}

function test_config(path) {
	let p = popen(MIHOMO_BIN + ' -d /etc/mihomo -f ' + path + ' -t 2>&1', 'r');
	let output = '';
	let rc = 1;
	if (p != null) {
		output = p.read('all');
		rc = p.close();
	}
	return { ok: (rc == 0), output: output };
}

function current_active() {
	let a = read_file(ACTIVE_FILE);
	return (a == null) ? '' : trim(a);
}

function api_secret() {
	let c = read_file(MAIN_CONFIG);
	if (c == null) return '';
	let lines = split(c, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		let m = match(line, /^[ \t]*secret:[ \t]*"?([^" \t\r]+)"?/);
		if (m != null) return m[1];
	}
	return '';
}

function reload_mihomo() {
	let secret = api_secret();
	let url = API_URL + '/configs?force=true';
	let body = '{"path":"' + MAIN_CONFIG + '"}';
	if (secret != '') {
		return system([ '/usr/bin/curl', '-fsS', '--connect-timeout', '5', '--max-time', '15',
			'-H', 'Authorization: Bearer ' + secret, '-X', 'PUT', url, '-d', body ]) == 0;
	}
	return system([ '/usr/bin/curl', '-fsS', '--connect-timeout', '5', '--max-time', '15',
		'-X', 'PUT', url, '-d', body ]) == 0;
}

const DASHBOARD_FILE = '/etc/mixomo/dashboard_panel';

function dashboard_settings(panel) {
	if (panel == 'zashboard') return [ 'external-controller: 0.0.0.0:9090', 'external-ui: ./UI/zashboard/', 'external-ui-url: "https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip"' ];
	if (panel == 'metacubex') return [ 'external-controller: 0.0.0.0:9090', 'external-ui: ./UI/metacubex/', 'external-ui-url: "https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz"' ];
	return null;
}

function read_dashboard_panel() {
	let p = trim(read_file(DASHBOARD_FILE) || '');
	return (p == 'zashboard' || p == 'metacubex') ? p : '';
}

function set_dashboard_panel(panel) {
	if (panel != '' && panel != 'zashboard' && panel != 'metacubex')
		return { ok: false, error: 'Недопустимая панель' };
	mkdir_p('/etc/mixomo');
	if (!write_file(DASHBOARD_FILE, panel + '\n')) return { ok: false, error: 'Не удалось сохранить панель' };
	return { ok: true };
}

function ensure_dashboard(path, panel) {
	let settings = dashboard_settings(panel);
	if (settings == null) return true;
	let s = read_file(path);
	if (s == null) return false;
	let lines = split(s, '\n');
	let has_controller = false, has_ui = false;
	for (let i = 0; i < length(lines); i++) {
		if (match(lines[i], /^external-controller:/) != null) has_controller = true;
		if (match(lines[i], /^external-ui:/) != null) has_ui = true;
	}
	if (has_controller && has_ui) return true;
	let out = [];
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^external-controller:/) != null) continue;
		if (match(line, /^external-ui:/) != null) continue;
		if (match(line, /^external-ui-url:/) != null) continue;
		push(out, line);
	}
	return write_file(path, join('\n', settings) + '\n' + join('\n', out));
}

function apply_profile(name, panel) {
	if (name == null || name == '' || name == '-') return { ok: false, error: 'Недопустимый профиль' };
	let prof = PROFILES_DIR + '/' + name + '.yaml';
	if (read_file(prof) == null) return { ok: false, error: 'Профиль не найден' };
	normalize_config(prof);
	let t = test_config(prof);
	if (!t.ok) return { ok: false, error: 'Профиль не проходит проверку Mihomo: ' + trim(t.output) };

	let active_panel = (panel == 'zashboard' || panel == 'metacubex') ? panel : read_dashboard_panel();
	let prev = read_file(MAIN_CONFIG);
	if (prev != null) write_file(MAIN_CONFIG + '.previous', prev);
	let tmp = '/tmp/mixomo-config.new';
	write_file(tmp, read_file(prof));
	system([ '/bin/mv', tmp, MAIN_CONFIG ]);
	if (active_panel != '') {
		ensure_dashboard(MAIN_CONFIG, active_panel);
		mkdir_p('/etc/mixomo');
		write_file(DASHBOARD_FILE, active_panel + '\n');
	}

	if (!reload_mihomo()) {
		system([ '/etc/init.d/mihomo', 'restart' ]);
		if (system([ '/etc/init.d/mihomo', 'running' ]) != 0) {
			if (read_file(MAIN_CONFIG + '.previous') != null) {
				write_file(MAIN_CONFIG, read_file(MAIN_CONFIG + '.previous'));
				system([ '/etc/init.d/mihomo', 'restart' ]);
			}
			return { ok: false, error: 'Не удалось применить профиль. Восстановлена предыдущая конфигурация.' };
		}
	}
	mkdir_p(MIXOMO_PROFILES);
	write_file(ACTIVE_FILE, name + '\n');
	return { ok: true };
}

export {
	MIXOMO_PROFILES, STATE_FILE, ACTIVE_FILE, PROFILES_DIR, RULES_DIR, RULES_STATE,
	MAIN_CONFIG, DEFAULT_CONFIG, MIHOMO_BIN, API_URL, SCHED_DIR, TIME_FILE,
	TRIGGER_FILE, DEFAULT_FILE, read_file, write_file, mkdir_p, file_exists,
	clean_name, valid_name, download_to, read_table, write_table, lookup_row,
	state_update, state_touch, extract_section, remove_section,
	extract_anchor_sections, extract_external_anchor_sections, prefix_before_proxies,
	from_proxies, strip_trailing_blanks, append_block, has_section, build_full_config,
	build_selected_config, build_refresh_full_config, build_refresh_selected_config,
	normalize_config, test_config, current_active, apply_profile,
	read_dashboard_panel, set_dashboard_panel
};
