'use strict';

import { readfile, writefile, access, popen, unlink } from 'fs';
import { cursor } from 'uci';

const uci = cursor();
uci.load('network');
uci.load('firewall');

const PREFIX = 'mihomo_route_';
const TABLE_SECTION = 'mihomo_routing_table';
const ROUTER_MARK = '0x233';
const ROUTER_NFT = '/etc/mihomo/mihomo-router-routing.nft';
const ROUTER_CHAIN = 'mihomo_router_routing';
const ROUTER_FW_SECTION = 'mihomo_router_routing';

const LOCAL_DEFAULT = '127.0.0.0/8, 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 100.64.0.0/10, 169.254.0.0/16';

let uid = 0;
function new_id() {
	uid++;
	return time() + '_' + uid;
}

function run(cmd) {
	let p = popen(cmd, 'r');
	if (p == null) return '';
	let out = p.read('all');
	p.close();
	return (out == null) ? '' : out;
}

function ip_rules() { return run('ip rule list 2>/dev/null'); }
function ip_routes_table(t) { return run('ip -4 route show table ' + t + ' 2>/dev/null'); }
function kernel_routes() { return run('ip -4 route show table main proto kernel scope link 2>/dev/null'); }

// foreach over network sections as array of section objects
function sections() {
	let out = [];
	uci.foreach('network', null, function(section) {
		if (section != null) push(out, section);
	});
	return out;
}

function list_client_sections() {
	let out = [];
	let secs = sections();
	for (let i = 0; i < length(secs); i++) {
		let sec = secs[i];
		if (sec == null) continue;
		let t = sec['.type'];
		if ((t == 'rule' || t == 'mihomo_rule') && substr(sec['.name'], 0, length(PREFIX + 'client_')) == PREFIX + 'client_')
			push(out, sec['.name']);
	}
	return out;
}

function list_excl_sections() {
	let out = [];
	let secs = sections();
	for (let i = 0; i < length(secs); i++) {
		let sec = secs[i];
		if (sec == null) continue;
		if (sec['.type'] == 'mihomo_excl' && substr(sec['.name'], 0, length(PREFIX + 'excl_')) == PREFIX + 'excl_')
			push(out, sec['.name']);
	}
	return out;
}

function section_exists(name) {
	return uci.get('network', name) != null;
}

function valid_id(value) {
	return value != null && value != '' && match(value, /^[A-Za-z0-9_.-]+$/) != null;
}

function get_opt(section, option) {
	let v = uci.get('network', section, option);
	return (v == null) ? '' : v;
}

function duplicate_client_source(source, skip_id) {
	let ids = list_client_sections();
	for (let i = 0; i < length(ids); i++) {
		let id = substr(ids[i], length(PREFIX + 'client_'));
		if (id != skip_id && get_opt(ids[i], 'src') == source) return true;
	}
	return false;
}

function duplicate_exclusion_dest(dest, skip_id) {
	let ids = list_excl_sections();
	for (let i = 0; i < length(ids); i++) {
		let id = substr(ids[i], length(PREFIX + 'excl_'));
		if (id != skip_id && get_opt(ids[i], 'dest') == dest) return true;
	}
	return false;
}

function set_opt(section, option, value) {
	return uci.set('network', section, option, value);
}

function valid_ipv4_cidr(value) {
	let has_mask = index(value, '/') >= 0;
	let mask = has_mask ? substr(value, index(value, '/') + 1) : '32';
	if (match(mask, /^[0-9]+$/) == null) return false;
	let m = int(mask);
	if (m < 0 || m > 32) return false;
	let ip = has_mask ? substr(value, 0, index(value, '/')) : value;
	let octets = split(ip, '.');
	if (length(octets) != 4) return false;
	for (let i = 0; i < length(octets); i++) {
		let oct = octets[i];
		if (match(oct, /^[0-9]+$/) == null) return false;
		if (int(oct) > 255) return false;
	}
	return true;
}

function normalize_ipv4_cidr(value) {
	if (index(value, '/') >= 0) return value;
	let octets = split(value, '.');
	let mask = 32;
	if (octets[1] == '0' && octets[2] == '0' && octets[3] == '0') mask = 8;
	else if (octets[2] == '0' && octets[3] == '0') mask = 16;
	else if (octets[3] == '0') mask = 24;
	return value + '/' + mask;
}

function find_table() {
	let existing = uci.get('network', TABLE_SECTION, 'table');
	if (existing != null && int(existing) >= 1) return existing;
	let table = 100;
	while (table < 1000) {
		if (run('ip route show table ' + table + ' 2>/dev/null') == '' &&
		    index(ip_rules(), 'lookup ' + table) < 0) {
			return table;
		}
		table++;
	}
	return null;
}

function has_default_via_mihomo(t) {
	let lines = split(ip_routes_table(t), '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		if (match(line, /^default[ \t]/) != null && index(line, 'dev Mihomo') >= 0)
			return true;
	}
	return false;
}

function ensure_rule(name, type) {
	if (uci.get('network', name) == null)
		uci.set('network', name, type);
}

function apply_network() {
	uci.commit('network');
	system([ '/etc/init.d/network', 'reload' ]);
	sleep(1000);
	let table = uci.get('network', TABLE_SECTION, 'table');
	if (table != null && !has_default_via_mihomo(table))
		system([ 'ip', 'route', 'replace', 'default', 'dev', 'Mihomo', 'table', table ]);
}

function rebuild_mixomo_redir() {
	if (access('/etc/mixomo/routing/redir', 'x'))
		system([ '/etc/mixomo/routing/redir' ]);
}

function network_sync() {
	uci.commit('network');
	system([ '/etc/init.d/network', 'reload' ]);
	sleep(1000);
	let table = uci.get('network', TABLE_SECTION, 'table');
	if (table != null && !has_default_via_mihomo(table))
		system([ 'ip', 'route', 'replace', 'default', 'dev', 'Mihomo', 'table', table ]);
	rebuild_mixomo_redir();
}

function ensure_base() {
	let table = find_table();
	if (table == null) return null;

	if (uci.get('network', TABLE_SECTION) == null)
		uci.set('network', TABLE_SECTION, 'route');
	set_opt(TABLE_SECTION, 'interface', 'Mihomo');
	set_opt(TABLE_SECTION, 'target', '0.0.0.0/0');
	set_opt(TABLE_SECTION, 'table', table);

	let secs = sections();
	for (let i = 0; i < length(secs); i++) {
		let sec = secs[i];
		if (sec == null) continue;
		if (sec['.type'] == 'rule' && substr(sec['.name'], 0, length(PREFIX + 'local_')) == PREFIX + 'local_')
			uci.delete('network', sec['.name']);
	}
	let number = 0;
	let lines = split(kernel_routes(), '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		let parts = split(line, ' ');
		let subnet = parts[0];
		if (subnet == null || index(subnet, '/') < 0) continue;
		if (index(line, 'dev Mihomo') >= 0) continue;
		let s = PREFIX + 'local_' + number;
		uci.set('network', s, 'rule');
		set_opt(s, 'name', 'Mixomo-local-' + number);
		set_opt(s, 'priority', 10000 + number);
		set_opt(s, 'dest', subnet);
		set_opt(s, 'lookup', 'main');
		number++;
	}
	return table;
}

function ensure_router_policy(table) {
	if (index(ip_rules(), '19000:') < 0 || index(ip_rules(), 'lookup ' + table) < 0)
		system([ 'ip', 'rule', 'add', 'priority', '19000', 'fwmark', ROUTER_MARK, 'lookup', table ]);
}

function local_ipv4_nft_set() {
	let local_nets = LOCAL_DEFAULT;
	let lines = split(kernel_routes(), '\n');
	for (let i = 0; i < length(lines); i++) {
		let line = lines[i];
		let parts = split(line, ' ');
		if (index(parts[0], '/') >= 0)
			local_nets += ', ' + parts[0];
	}
	let ids = list_excl_sections();
	for (let i = 0; i < length(ids); i++) {
		let id = ids[i];
		if (get_opt(id, 'disabled') == '1') continue;
		let d = get_opt(id, 'dest');
		if (d != '') local_nets += ', ' + d;
	}
	return local_nets;
}

function enable_router_mark() {
	let local_nets = local_ipv4_nft_set();
	let nft = 'chain ' + ROUTER_CHAIN + ' {\n' +
		'    type route hook output priority mangle; policy accept;\n' +
		'    ip daddr { ' + local_nets + ' } return\n' +
		'    ip daddr 224.0.0.0/4 return\n' +
		'    ip daddr 255.255.255.255 return\n' +
		'    meta nfproto ipv4 meta mark 0 meta mark set ' + ROUTER_MARK + '\n' +
		'}';
	writefile(ROUTER_NFT, nft);
	if (uci.get('firewall', ROUTER_FW_SECTION) == null)
		uci.set('firewall', ROUTER_FW_SECTION, 'include');
	uci.set('firewall', ROUTER_FW_SECTION, 'type', 'nftables');
	uci.set('firewall', ROUTER_FW_SECTION, 'path', ROUTER_NFT);
	uci.set('firewall', ROUTER_FW_SECTION, 'enabled', '1');
	uci.commit('firewall');
	system([ '/etc/init.d/firewall', 'reload' ]);
	if (system([ 'nft', 'list', 'chain', 'inet', 'fw4', ROUTER_CHAIN ]) != 0) {
		system([ 'nft', 'add', 'chain', 'inet', 'fw4', ROUTER_CHAIN, '{ type route hook output priority mangle; policy accept; }' ]);
		system([ 'nft', 'add', 'rule', 'inet', 'fw4', ROUTER_CHAIN, 'ip', 'daddr', '{ ' + local_nets + ' }', 'return' ]);
		system([ 'nft', 'add', 'rule', 'inet', 'fw4', ROUTER_CHAIN, 'ip', 'daddr', '224.0.0.0/4', 'return' ]);
		system([ 'nft', 'add', 'rule', 'inet', 'fw4', ROUTER_CHAIN, 'ip', 'daddr', '255.255.255.255', 'return' ]);
		system([ 'nft', 'add', 'rule', 'inet', 'fw4', ROUTER_CHAIN, 'meta', 'nfproto', 'ipv4', 'meta', 'mark', '0', 'meta', 'mark', 'set', ROUTER_MARK ]);
	}
}

function disable_router_mark() {
	system([ 'nft', 'delete', 'table', 'inet', 'mihomo_router_routing' ]);
	unlink(ROUTER_NFT);
	if (uci.get('firewall', ROUTER_FW_SECTION) != null)
		uci.delete('firewall', ROUTER_FW_SECTION);
	uci.commit('firewall');
	system([ '/etc/init.d/firewall', 'reload' ]);
}

function cleanup_if_unused() {
	if (length(list_client_sections()) > 0) return;
	if (section_exists(PREFIX + 'router')) return;
	let table = uci.get('network', TABLE_SECTION, 'table');
	let del = [];
	let secs = sections();
	for (let i = 0; i < length(secs); i++) {
		let sec = secs[i];
		if (sec == null) continue;
		if (sec['.type'] == 'rule' && substr(sec['.name'], 0, length(PREFIX + 'local_')) == PREFIX + 'local_')
			push(del, sec['.name']);
	}
	for (let i = 0; i < length(del); i++)
		uci.delete('network', del[i]);
	if (uci.get('network', TABLE_SECTION) != null)
		uci.delete('network', TABLE_SECTION);
	uci.commit('network');
	system([ '/etc/init.d/network', 'reload' ]);
	if (table != null)
		system([ 'ip', 'route', 'flush', 'table', table ]);
	disable_router_mark();
}

function prefix_len(value) {
	return (index(value, '/') >= 0) ? int(substr(value, index(value, '/') + 1)) : 32;
}

function next_priority(cidr, skip) {
	let base = 20000 + (32 - prefix_len(cidr)) * 100;
	let seq = 0;
	while (true) {
		let p = base + seq;
		let used = false;
		let ids = list_client_sections();
		for (let i = 0; i < length(ids); i++) {
			let id = ids[i];
			let key = substr(id, length(PREFIX + 'client_'));
			if (key == skip) continue;
			if (get_opt(id, 'priority') == ('' + p)) { used = true; break; }
		}
		if (!used) return p;
		seq++;
	}
}

function get_backend_default() {
	let state = readfile('/etc/mixomo/routing/redir-port');
	if (state != null)
		return 'redir-tproxy';
	let c = readfile('/etc/mihomo/config.yaml');
	if (c == null) return 'tun-socks5';
	let lines = split(c, '\n');
	for (let i = 0; i < length(lines); i++)
		if (match(lines[i], /^[ \t]*redir-port:[ \t]*[0-9]+/) != null)
			return 'redir-tproxy';
	return 'tun-socks5';
}

function udp443_enabled() {
	let t = uci.get('firewall', 'Block_443_UDP');
	return (t != null && t == 'rule' && uci.get('firewall', 'Block_443_UDP', 'disabled') != '1');
}

function emit_status() {
	let table = uci.get('network', TABLE_SECTION, 'table');
	let router = 0;
	if (get_opt(PREFIX + 'router', 'mark') == ROUTER_MARK) router = 1;
	let variant = get_backend_default();

	let rules = [];
	let client_ids = list_client_sections();
	for (let i = 0; i < length(client_ids); i++) {
		let id = client_ids[i];
		let prio = get_opt(id, 'priority');
		push(rules, {
			id: substr(id, length(PREFIX + 'client_')),
			source: get_opt(id, 'src'),
			label: get_opt(id, 'name'),
			backend: get_opt(id, 'backend'),
			priority: (prio == '') ? 0 : int(prio),
			enabled: (get_opt(id, 'disabled') != '1') ? 1 : 0
		});
	}
	let exclusions = [];
	let excl_ids = list_excl_sections();
	for (let i = 0; i < length(excl_ids); i++) {
		let id = excl_ids[i];
		let prio = get_opt(id, 'priority');
		push(exclusions, {
			id: substr(id, length(PREFIX + 'excl_')),
			dest: get_opt(id, 'dest'),
			label: get_opt(id, 'name'),
			priority: (prio == '') ? 0 : int(prio),
			enabled: (get_opt(id, 'disabled') != '1') ? 1 : 0
		});
	}

	return {
		ok: true,
		table: (table == null) ? 0 : int(table),
		router: !!router,
		variant: variant,
		redirAvailable: (variant == 'redir-tproxy') ? 1 : 0,
		udp443: udp443_enabled() ? 1 : 0,
		rules: rules,
		exclusions: exclusions
	};
}

function emit_clients() {
	let clients = [];
	let seen = {};

	let ips = [];
	let addr_lines = split(run('ip -4 addr show 2>/dev/null'), '\n');
	for (let i = 0; i < length(addr_lines); i++) {
		let line = addr_lines[i];
		if (match(line, '.*inet [0-9.]+/.*') != null)
			push(ips, line);
	}
	let route_lines = split(run('ip -4 route show 2>/dev/null'), '\n');
	for (let i = 0; i < length(route_lines); i++) {
		let line = route_lines[i];
		if (line == '') continue;
		let parts = split(line, ' ');
		if (parts == null) continue;
		for (let i = 1; i < length(parts); i++)
			if (parts[i] == 'via')
				push(ips, parts[i + 1]);
	}
	let router_ips = {};
	for (let i = 0; i < length(ips); i++) router_ips[ips[i]] = 1;

	function is_router_ip(ip) {
		return exists(router_ips, ip);
	}

	let leases = readfile('/tmp/dhcp.leases');
	if (leases != null) {
		let lease_lines = split(leases, '\n');
		for (let i = 0; i < length(lease_lines); i++) {
			let line = lease_lines[i];
			if (line == '') continue;
			let parts = split(line, ' ');
			if (parts == null || length(parts) < 3) continue;
			let ip = parts[2];
			if (ip == null || !valid_ipv4_cidr(ip)) continue;
			if (seen[ip] || is_router_ip(ip)) continue;
			seen[ip] = 1;
			push(clients, { ip: ip, mac: (parts[1] == null) ? '' : parts[1], name: (parts[3] == null) ? '' : parts[3] });
		}
	}
	let neigh_lines = split(run('ip -4 neigh show 2>/dev/null'), '\n');
	for (let i = 0; i < length(neigh_lines); i++) {
		let line = neigh_lines[i];
		if (line == '') continue;
		let parts = split(line, ' ');
		if (parts == null || length(parts) < 1) continue;
		let ip = parts[0];
		if (ip == null || !valid_ipv4_cidr(ip)) continue;
		if (index(line, 'FAILED') >= 0) continue;
		if (seen[ip] || is_router_ip(ip)) continue;
		let mac = '';
		for (let i = 1; i < length(parts) - 1; i++)
			if (parts[i] == 'lladdr') { mac = parts[i + 1]; break; }
		seen[ip] = 1;
		push(clients, { ip: ip, mac: mac, name: '' });
	}

	return { ok: true, clients: clients };
}

function set_udp443(enabled) {
	if (uci.get('firewall', 'Block_443_UDP') != null)
		uci.delete('firewall', 'Block_443_UDP');
	if (enabled) {
		uci.set('firewall', 'Block_443_UDP', 'rule');
		uci.set('firewall', 'Block_443_UDP', 'name', 'Block-443-UDP');
		uci.set('firewall', 'Block_443_UDP', 'src', 'wan');
		uci.set('firewall', 'Block_443_UDP', 'dest', '*');
		uci.set('firewall', 'Block_443_UDP', 'family', 'any');
		uci.set('firewall', 'Block_443_UDP', 'proto', 'udp');
		uci.set('firewall', 'Block_443_UDP', 'dest_port', '443');
		uci.set('firewall', 'Block_443_UDP', 'target', 'REJECT');
	}
	uci.commit('firewall');
	system([ '/etc/init.d/firewall', 'reload' ]);
}

function finalize() {
	if (access('/etc/init.d/magitrickle', 'x'))
		system([ '/etc/init.d/magitrickle', 'restart' ]);
	return emit_status();
}

const methods = {
	status: { call: emit_status },
	clients: { call: emit_clients },

	set_udp443: {
		args: { enabled: true },
		call: function(req) {
			set_udp443(!!req.args.enabled);
			return emit_status();
		}
	},

	set_router: {
		args: { enabled: true },
		call: function(req) {
			let enabled = !!req.args.enabled;
			let table = ensure_base();
			if (table == null) return { ok: false, error: 'Не удалось подобрать свободную таблицу маршрутизации' };
			if (enabled) {
				ensure_rule(PREFIX + 'router', 'rule');
				set_opt(PREFIX + 'router', 'name', 'Mixomo-router');
				if (uci.get('network', PREFIX + 'router', 'src') != null)
					uci.delete('network', PREFIX + 'router', 'src');
				set_opt(PREFIX + 'router', 'priority', '19000');
				set_opt(PREFIX + 'router', 'mark', ROUTER_MARK);
				set_opt(PREFIX + 'router', 'lookup', table);
				enable_router_mark();
				apply_network();
				ensure_router_policy(table);
			} else {
				system([ 'ip', 'rule', 'del', 'priority', '19000', 'fwmark', ROUTER_MARK ]);
				if (uci.get('network', PREFIX + 'router') != null)
					uci.delete('network', PREFIX + 'router');
				cleanup_if_unused();
				if (uci.get('network', TABLE_SECTION, 'table') != null)
					system([ '/etc/init.d/network', 'reload' ]);
			}
			return emit_status();
		}
	},

	exclude_add: {
		args: { dest: 'string', label: 'string' },
		call: function(req) {
			let dest = req.args.dest;
			let label = req.args.label;
			if (!valid_ipv4_cidr(dest)) return { ok: false, error: 'Введите корректный IPv4-адрес или CIDR' };
			dest = normalize_ipv4_cidr(dest);
			if (duplicate_exclusion_dest(dest, '')) return { ok: false, error: 'Такое исключение уже существует' };
			if (length(label) > 64) return { ok: false, error: 'Название не длиннее 64 символов' };
			if (index(label, '\n') >= 0 || index(label, '\r') >= 0 || index(label, '\t') >= 0) return { ok: false, error: 'Недопустимое название' };

			let sec = PREFIX + 'excl_' + new_id();
			uci.set('network', sec, 'mihomo_excl');
			set_opt(sec, 'dest', dest);
			set_opt(sec, 'name', (label == '') ? dest : label);
			set_opt(sec, 'priority', 1000 + length(list_excl_sections()));
			uci.commit('network');
			rebuild_mixomo_redir();
			return emit_status();
		}
	},

	exclude_delete: {
		args: { id: 'string' },
		call: function(req) {
			if (!valid_id(req.args.id)) return { ok: false, error: 'Некорректный идентификатор' };
			let sec = PREFIX + 'excl_' + req.args.id;
			if (!section_exists(sec)) return { ok: false, error: 'Исключение не найдено' };
			uci.delete('network', sec);
			uci.commit('network');
			rebuild_mixomo_redir();
			return emit_status();
		}
	},

	exclude_update: {
		args: { id: 'string', dest: 'string', label: 'string' },
		call: function(req) {
			if (!valid_id(req.args.id)) return { ok: false, error: 'Некорректный идентификатор' };
			let sec = PREFIX + 'excl_' + req.args.id;
			if (!section_exists(sec)) return { ok: false, error: 'Исключение не найдено' };
			let dest = req.args.dest;
			let label = req.args.label;
			if (!valid_ipv4_cidr(dest)) return { ok: false, error: 'Введите корректный IPv4-адрес или CIDR' };
			dest = normalize_ipv4_cidr(dest);
			if (duplicate_exclusion_dest(dest, req.args.id)) return { ok: false, error: 'Такое исключение уже существует' };
			if (length(label) > 64) return { ok: false, error: 'Название не длиннее 64 символов' };
			if (index(label, '\n') >= 0 || index(label, '\r') >= 0 || index(label, '\t') >= 0) return { ok: false, error: 'Недопустимое название' };
			set_opt(sec, 'dest', dest);
			set_opt(sec, 'name', (label == '') ? dest : label);
			uci.commit('network');
			rebuild_mixomo_redir();
			return emit_status();
		}
	},

	exclude_set_enabled: {
		args: { id: 'string', enabled: true },
		call: function(req) {
			if (!valid_id(req.args.id)) return { ok: false, error: 'Некорректный идентификатор' };
			let sec = PREFIX + 'excl_' + req.args.id;
			if (!section_exists(sec)) return { ok: false, error: 'Исключение не найдено' };
			if (req.args.enabled)
				uci.delete('network', sec, 'disabled');
			else
				set_opt(sec, 'disabled', '1');
			uci.commit('network');
			rebuild_mixomo_redir();
			return emit_status();
		}
	},

	reorder: {
		args: { type: 'string', order: 'string' },
		call: function(req) {
			let ids = (req.args.order == null || req.args.order == '') ? [] : split(req.args.order, ',');
			let n = 0;
			for (let i = 0; i < length(ids); i++) {
				if (ids[i] == null) continue;
				if (req.args.type == 'rule')
					set_opt(PREFIX + 'client_' + ids[i], 'priority', 20000 + n);
				else
					set_opt(PREFIX + 'excl_' + ids[i], 'priority', 1000 + n);
				n++;
			}
			uci.commit('network');
			rebuild_mixomo_redir();
			return emit_status();
		}
	},

	add: {
		args: { source: 'string', label: 'string', backend: 'string' },
call: function(req) {
			let source = req.args.source;
			let label = req.args.label;
			let backend = req.args.backend;
			if (!valid_ipv4_cidr(source)) return { ok: false, error: 'Введите корректный IPv4-адрес или CIDR' };
			source = normalize_ipv4_cidr(source);
			if (duplicate_client_source(source, '')) return { ok: false, error: 'Такое правило уже существует' };
			if (length(label) > 64) return { ok: false, error: 'Название не длиннее 64 символов' };
			if (index(label, '\n') >= 0 || index(label, '\r') >= 0 || index(label, '\t') >= 0) return { ok: false, error: 'Недопустимое название' };
			if (backend == '') backend = get_backend_default();
			if (backend != 'redir-tproxy' && backend != 'tun-socks5') return { ok: false, error: 'Неизвестный backend' };

			let sec = PREFIX + 'client_' + new_id();
			uci.set('network', sec, (backend == 'redir-tproxy') ? 'mihomo_rule' : 'rule');
			set_opt(sec, 'backend', backend);
			set_opt(sec, 'priority', next_priority(source, ''));
			set_opt(sec, 'src', source);
			set_opt(sec, 'name', (label == '') ? source : label);
			if (backend == 'redir-tproxy') {
				if (uci.get('network', sec, 'lookup') != null)
					uci.delete('network', sec, 'lookup');
				uci.commit('network');
				network_sync();
			} else {
				let table = ensure_base();
				if (table == null) return { ok: false, error: 'Не удалось подобрать свободную таблицу маршрутизации' };
				set_opt(sec, 'lookup', table);
				uci.commit('network');
				apply_network();
				rebuild_mixomo_redir();
			}
			return emit_status();
		}
	},

	update: {
		args: { id: 'string', source: 'string', label: 'string', backend: 'string' },
		call: function(req) {
			if (!valid_id(req.args.id)) return { ok: false, error: 'Некорректный идентификатор' };
			let sec = PREFIX + 'client_' + req.args.id;
			if (!section_exists(sec)) return { ok: false, error: 'Правило не найдено' };
			let source = req.args.source;
			let label = req.args.label;
			let backend = req.args.backend;
			if (!valid_ipv4_cidr(source)) return { ok: false, error: 'Введите корректный IPv4-адрес или CIDR' };
			source = normalize_ipv4_cidr(source);
			if (duplicate_client_source(source, req.args.id)) return { ok: false, error: 'Такое правило уже существует' };
			if (length(label) > 64) return { ok: false, error: 'Название не длиннее 64 символов' };
			if (index(label, '\n') >= 0 || index(label, '\r') >= 0 || index(label, '\t') >= 0) return { ok: false, error: 'Недопустимое название' };
			if (backend == '') backend = get_opt(sec, 'backend');
			if (backend == '') backend = get_backend_default();
			if (backend != 'redir-tproxy' && backend != 'tun-socks5') return { ok: false, error: 'Неизвестный backend' };

			set_opt(sec, 'src', source);
			set_opt(sec, 'name', (label == '') ? source : label);
			set_opt(sec, 'priority', next_priority(source, req.args.id));
			set_opt(sec, 'backend', backend);
			if (backend == 'redir-tproxy') {
				uci.set('network', sec, 'mihomo_rule');
				if (uci.get('network', sec, 'lookup') != null)
					uci.delete('network', sec, 'lookup');
				uci.commit('network');
				network_sync();
			} else {
				let table = ensure_base();
				if (table == null) return { ok: false, error: 'Не удалось подготовить таблицу маршрутизации' };
				uci.set('network', sec, 'rule');
				set_opt(sec, 'lookup', table);
				uci.commit('network');
				apply_network();
				rebuild_mixomo_redir();
			}
			return emit_status();
		}
	},

	'delete': {
		args: { id: 'string' },
		call: function(req) {
			let sec = PREFIX + 'client_' + req.args.id;
			if (!section_exists(sec)) return { ok: false, error: 'Правило не найдено' };
			let table = uci.get('network', TABLE_SECTION, 'table');
			uci.delete('network', sec);
			cleanup_if_unused();
			uci.commit('network');
			if (uci.get('network', TABLE_SECTION, 'table') != null)
				system([ '/etc/init.d/network', 'reload' ]);
			rebuild_mixomo_redir();
			return emit_status();
		}
	},

	set_enabled: {
		args: { id: 'string', enabled: true },
		call: function(req) {
			let sec = PREFIX + 'client_' + req.args.id;
			if (!section_exists(sec)) return { ok: false, error: 'Правило не найдено' };
			let backend = get_opt(sec, 'backend');
			if (backend == '') backend = get_backend_default();
			let prio = get_opt(sec, 'priority');
			if (req.args.enabled) {
				if (uci.get('network', sec, 'disabled') != null)
					uci.delete('network', sec, 'disabled');
			} else {
				set_opt(sec, 'disabled', '1');
			}
			uci.commit('network');
			network_sync();
			return emit_status();
		}
	}
};

export { methods };