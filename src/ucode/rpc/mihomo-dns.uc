'use strict';

import { readfile, writefile } from 'fs';

const DNS_CONF = '/etc/dnsmasq.conf';
const DNS_MARK_START = '# Rules from Mixomo';
const DNS_MARK_END = '# End rules from Mixomo';
const DNS_CUSTOM_FILE = '/etc/mixomo/dns/custom';
const DNS_ORDER_FILE = '/etc/mixomo/dns/order';

function has_suffix(s, suf) {
	return length(s) >= length(suf) && substr(s, length(s) - length(suf)) == suf;
}

function extract_dns_block() {
	let content = readfile(DNS_CONF);
	if (content == null)
		return '';

	let out = [];
	let inside = false;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (line == DNS_MARK_START) { inside = true; continue; }
		if (line == DNS_MARK_END) { inside = false; continue; }
		if (inside)
			push(out, line);
	}
	return join('\n', out);
}

function without_markers(content) {
	if (content == null)
		return '';

	let out = [];
	let inside = false;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (line == DNS_MARK_START) { inside = true; continue; }
		if (line == DNS_MARK_END) { inside = false; continue; }
		if (inside)
			continue;
		push(out, line);
	}
	while (length(out) > 0 && out[length(out) - 1] == '')
		pop(out);
	return join('\n', out);
}

function restart_dnsmasq() {
	system([ '/etc/init.d/dnsmasq', 'restart' ]);
}

function custom_name(line) {
	let parts = split(line, '\t');
	if (parts[1] == null) parts = split(line, '\\t');
	return parts[0];
}

function custom_names() {
	let names = [];
	let content = readfile(DNS_CUSTOM_FILE);
	if (content == null) return names;
	let lines = split(content, '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		let parts = split(line, '\t');
		if (parts[1] == null) parts = split(line, '\\t');
		if (parts[0] != '' && parts[1] != null && parts[1] != '' && index(names, parts[0]) < 0)
			push(names, parts[0]);
	}
	return names;
}

function write_order(names) {
	system([ '/bin/mkdir', '-p', '/etc/mixomo/dns' ]);
	return writefile(DNS_ORDER_FILE, length(names) ? join('\n', names) + '\n' : '');
}

const methods = {
	status: {
		call: function() {
			let conf = readfile(DNS_CONF);
			let block = extract_dns_block();
			let no_resolv = 0, strict_order = 0, all_servers = 0;
			let servers = [];
			let server_lines = split(block, '\n');
			for (let i = 0; i < length(server_lines); i++) {
				let line = server_lines[i];
				if (line == 'no-resolv') no_resolv = 1;
				else if (line == 'strict-order') strict_order = 1;
				else if (line == 'all-servers') all_servers = 1;
				else if (index(line, 'server=') == 0)
					push(servers, substr(line, 7));
			}

			let custom = [];
			let c = readfile(DNS_CUSTOM_FILE);
			if (c != null) {
				let custom_lines = split(c, '\n');
			for (let i = 0; i < length(custom_lines); i++) {
				let line = custom_lines[i];
					if (line == '')
						continue;
				let parts = split(line, '\t');
				if (parts[1] == null) parts = split(line, '\\t');
				if (parts[0] == '' || parts[1] == null || parts[1] == '') continue;
				push(custom, { name: parts[0], value: parts[1] });
				}
			}

			let order = [];
			let saved_order = readfile(DNS_ORDER_FILE);
			let available = [];
			for (let i = 0; i < length(custom); i++) push(available, custom[i].name);
			if (saved_order != null) {
				let order_lines = split(saved_order, '\n');
				for (let i = 0; i < length(order_lines); i++) {
					let saved_names = split(order_lines[i], ',');
					for (let j = 0; j < length(saved_names); j++) {
						let name = replace(saved_names[j], /^[ \r\n]+|[ \r\n]+$/g, '');
						if (name != '' && index(available, name) >= 0 && index(order, name) < 0) push(order, name);
					}
				}
			}
			for (let i = 0; i < length(available); i++)
				if (index(order, available[i]) < 0) push(order, available[i]);

			return {
				ok: true,
				config: conf || '',
				block: block,
				hasMarkers: (conf != null && index(conf, DNS_MARK_START) >= 0) ? 1 : 0,
				noResolv: !!no_resolv,
				strictOrder: !!strict_order,
				allServers: !!all_servers,
				servers: servers,
				custom: custom,
				order: order
			};
		}
	},

	apply: {
		args: { block: 'string', clean: true },
		call: function(req) {
			let block = req.args.block || '';
			let clean = !!req.args.clean;

			let base = clean ? '' : without_markers(readfile(DNS_CONF));
			let out = (base == '') ? '' : base + '\n';
			out += DNS_MARK_START + '\n' + block + '\n' + DNS_MARK_END + '\n';

			if (writefile(DNS_CONF, out) == null)
				return { ok: false, error: 'Не удалось записать /etc/dnsmasq.conf' };

			system([ '/etc/init.d/dnsmasq', 'restart' ]);
			return { ok: true };
		}
	},

	apply_full: {
		args: { config: 'string' },
		call: function(req) {
			if (writefile(DNS_CONF, req.args.config || '') == null)
				return { ok: false, error: 'Не удалось записать /etc/dnsmasq.conf' };
			restart_dnsmasq();
			return { ok: true };
		}
	},

	clear: {
		call: function() {
			let out = without_markers(readfile(DNS_CONF));
			writefile(DNS_CONF, out == '' ? '' : out + '\n');
			restart_dnsmasq();
			return { ok: true };
		}
	},

	set_order: {
		args: { names: 'string' },
		call: function(req) {
			let available = custom_names();
			let names = [];
			let requested = split(req.args.names || '', ',');
			for (let i = 0; i < length(requested); i++) {
				let name = replace(requested[i], /^[ \r\n]+|[ \r\n]+$/g, '');
				if (name != '' && index(available, name) >= 0 && index(names, name) < 0)
					push(names, name);
			}
			for (let i = 0; i < length(available); i++)
				if (index(names, available[i]) < 0) push(names, available[i]);
			if (write_order(names) == null)
				return { ok: false, error: 'Не удалось сохранить порядок DNS' };
			return { ok: true, order: names };
		}
	},

	rename_preset: {
		args: { old_name: 'string', name: 'string', value: 'string' },
		call: function(req) {
			let old_name = req.args.old_name || '';
			let name = replace(req.args.name || '', /^[ \r\n]+|[ \r\n]+$/g, '');
			let value = replace(req.args.value || '', /^[ \r\n]+|[ \r\n]+$/g, '');
			if (old_name == '' || name == '' || value == '') return { ok: false, error: 'Некорректные данные DNS' };
			if (name != old_name && index(custom_names(), name) >= 0) return { ok: false, error: 'Такой DNS уже добавлен' };
			let c = readfile(DNS_CUSTOM_FILE);
			if (c == null) return { ok: false, error: 'DNS-пресет не найден' };
			let lines = split(c, '\n');
			let out = [];
			let found = false;
			for (let i = 0; i < length(lines); i++) {
				let line = lines[i];
				if (index(line, old_name + '\t') == 0 || index(line, old_name + '\\t') == 0) {
					push(out, name + '\t' + value);
					found = true;
				} else if (line != '' || i < length(lines) - 1) push(out, line);
			}
			if (!found || writefile(DNS_CUSTOM_FILE, join('\n', out) + '\n') == null)
				return { ok: false, error: 'Не удалось сохранить DNS-пресет' };
			let order = [];
			let saved = readfile(DNS_ORDER_FILE);
			if (saved != null) {
				let saved_lines = split(saved, '\n');
				for (let i = 0; i < length(saved_lines); i++) {
					let names = split(saved_lines[i], ',');
					for (let j = 0; j < length(names); j++) {
						let item = names[j];
						if (item == old_name) item = name;
						if (item != '' && index(order, item) < 0) push(order, item);
					}
				}
			}
			if (index(order, name) < 0) push(order, name);
			if (write_order(order) == null) return { ok: false, error: 'Не удалось сохранить порядок DNS' };
			return { ok: true };
		}
	},

	add_preset: {
		args: { name: 'string', value: 'string' },
		call: function(req) {
			let name = replace(req.args.name || '', /^[ \r\n]+|[ \r\n]+$/g, '');
			let value = replace(req.args.value || '', /^[ \r\n]+|[ \r\n]+$/g, '');

			if (name == '') return { ok: false, error: 'Пустое название' };
			if (value == '') return { ok: false, error: 'Пустое значение DNS' };
			if (length(name) > 64) return { ok: false, error: 'Название не длиннее 64 символов' };
			if (index(name, '\n') >= 0 || index(name, '\r') >= 0 || index(name, '\t') >= 0) return { ok: false, error: 'Недопустимое название' };
			value = replace(value, / +/g, ' ');
			let dns_values = split(value, ' ');
			let normalized = [];
			for (let i = 0; i < length(dns_values); i++) {
				let dns_value = dns_values[i];
				if (dns_value == '') continue;
				if (match(dns_value, /[^A-Za-z0-9.#:\-@]/) != null) return { ok: false, error: 'Недопустимый DNS: ' + dns_value };
				let ip_part = replace(dns_value, /#.*$/, '');
				let octets = split(ip_part, '.');
				if (length(octets) != 4) return { ok: false, error: 'Укажите IPv4-адрес DNS' };
				for (let j = 0; j < length(octets); j++) {
					let oct = octets[j];
					if (match(oct, /^[0-9]+$/) == null) return { ok: false, error: 'Недопустимый DNS: ' + dns_value };
					if (length(oct) > 3) return { ok: false, error: 'Октет IP не длиннее 3 цифр: ' + oct };
				}
				push(normalized, dns_value);
			}
			if (length(normalized) == 0) return { ok: false, error: 'Пустое значение DNS' };
			value = join(' ', normalized);

			system([ '/bin/mkdir', '-p', '/etc/mixomo/dns' ]);
			let c = readfile(DNS_CUSTOM_FILE);
			if (c == null) c = '';
			let custom_lines = split(c, '\n');
			for (let i = 0; i < length(custom_lines); i++) {
				let line = custom_lines[i];
				if (index(line, name + '\t') == 0)
					return { ok: false, error: 'Такой DNS уже добавлен' };
			}

			let out = (c == '' || has_suffix(c, '\n')) ? c : c + '\n';
			out += name + '\t' + value + '\n';
			writefile(DNS_CUSTOM_FILE, out);
			return { ok: true };
		}
	},

	remove_preset: {
		args: { name: 'string' },
		call: function(req) {
			let name = req.args.name || '';
			let removed_custom = false;
			let c = readfile(DNS_CUSTOM_FILE);
			if (c != null) {
				let out = [];
				let custom_lines = split(c, '\n');
				for (let i = 0; i < length(custom_lines); i++) {
					let line = custom_lines[i];
					if (index(line, name + '\t') == 0 || index(line, name + '\\t') == 0) {
						removed_custom = true;
						continue;
					}
					push(out, line);
				}
				if (writefile(DNS_CUSTOM_FILE, join('\n', out) + '\n') == null)
					return { ok: false, error: 'Не удалось удалить DNS-пресет' };
			}
			let order = [];
			let saved = readfile(DNS_ORDER_FILE);
			if (saved != null) {
				let saved_lines = split(saved, '\n');
				for (let i = 0; i < length(saved_lines); i++) {
					let names = split(saved_lines[i], ',');
					for (let j = 0; j < length(names); j++)
						if (names[j] != '' && names[j] != name && index(order, names[j]) < 0) push(order, names[j]);
				}
			}
			if (write_order(order) == null)
				return { ok: false, error: 'Не удалось обновить порядок DNS' };
			return { ok: true };
		}
	}
};

return { 'mihomo-dns': methods };