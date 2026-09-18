'use strict';

import { readfile, writefile, unlink, popen, access, error } from 'fs';

const BACKUP_DIR = '/etc/mixomo/backups';
const SETTINGS_FILE = '/etc/mixomo/backup.conf';
const COMPONENTS = [ 'mihomo', 'dns', 'schedule', 'magitrickle', 'routing' ];

function valid_component(name) {
	return name == 'mihomo' || name == 'dns' || name == 'schedule' || name == 'magitrickle' || name == 'routing' || name == 'all';
}

function shell_quote(value) {
	return "'" + replace(value, "'", "'\\''") + "'";
}

function run_system(command) {
	let log = '/tmp/mixomo-backup-command.log';
	unlink(log);
	let code = system(command + ' >' + shell_quote(log) + ' 2>&1');
	let output = readfile(log);
	unlink(log);
	return { code: code, output: output == null ? '' : output };
}

function ensure_dir() {
	return run_system('/bin/mkdir -p ' + shell_quote(BACKUP_DIR));
}

function read_settings() {
	let result = { retention: 1, auto_mihomo: false, auto_magitrickle: false };
	let text = readfile(SETTINGS_FILE);
	if (text == null) return result;
	let lines = split(text, '\n');
	for (let i = 0; i < length(lines); i++) {
		let parts = split(lines[i], '=');
		if (length(parts) < 2) continue;
		if (parts[0] == 'retention') result.retention = int(parts[1]) || 5;
		else if (parts[0] == 'auto_mihomo') result.auto_mihomo = parts[1] == '1';
		else if (parts[0] == 'auto_magitrickle') result.auto_magitrickle = parts[1] == '1';
	}
	if (result.retention < 1) result.retention = 1;
	if (result.retention > 20) result.retention = 20;
	return result;
}

function save_settings(args) {
	let retention = int(args.retention || 1);
	if (retention < 1 || retention > 20) return { ok: false, error: 'Retention must be from 1 to 20' };
	let text = 'retention=' + retention + '\n' +
		'auto_mihomo=' + ((args.auto_mihomo == '1' || args.auto_mihomo == true) ? '1' : '0') + '\n' +
		'auto_magitrickle=' + ((args.auto_magitrickle == '1' || args.auto_magitrickle == true) ? '1' : '0') + '\n';
	let mkdir = ensure_dir();
	if (mkdir.code != 0) return { ok: false, error: 'Could not save backup settings: mkdir code=' + mkdir.code + ', output=' + mkdir.output };
	let written = writefile(SETTINGS_FILE, text);
	if (written == null)
		return { ok: false, error: 'Could not save backup settings: writefile=' + written + ', fs.error=' + (error() || 'unknown') };
	return { ok: true, settings: read_settings() };
}

function component_paths(component) {
	if (component == 'mihomo') return [ 'etc/mihomo/config.yaml', 'etc/mihomo/config.template.yaml', 'etc/mihomo/profiles', 'etc/mihomo/rule-files', 'etc/mixomo/profiles', 'etc/mixomo/order', 'etc/mixomo/schedule' ];
	if (component == 'dns') return [ 'etc/dnsmasq.conf', 'etc/mixomo/dns' ];
	if (component == 'schedule') return [ 'etc/mixomo/schedule' ];
	if (component == 'magitrickle') return [ 'etc/magitrickle/state', 'etc/config/magitrickle' ];
	if (component == 'routing') return [ 'etc/mixomo/routing' ];
	return [ 'etc/config', 'etc/mihomo', 'etc/mixomo/profiles', 'etc/mixomo/order', 'etc/mixomo/schedule', 'etc/mixomo/dns', 'etc/mixomo/routing', 'etc/mixomo/versions', 'etc/magitrickle/state', 'etc/dnsmasq.conf', 'etc/dropbear', 'etc/crontabs', 'etc/rc.local', 'etc/firewall.user', 'etc/sysupgrade.conf' ];
}

function create_backup(component) {
	if (!valid_component(component)) return { ok: false, error: 'Invalid backup component' };
	let mkdir = ensure_dir();
	if (mkdir.code != 0) return { ok: false, error: 'Could not create backup directory: system code=' + mkdir.code + ', output=' + mkdir.output };
	let filename = 'backup-' + time() + '-' + component + '.tar.gz';
	let output = BACKUP_DIR + '/' + filename;
	if (component == 'all' && access('/sbin/sysupgrade', 'x')) {
		let temporary = '/tmp/' + filename;
		let official = run_system('/sbin/sysupgrade -q -c -b ' + shell_quote(temporary) + ' && /bin/mv -f ' + shell_quote(temporary) + ' ' + shell_quote(output));
		if (official.code == 0)
			return { ok: true, file: filename, component: component };
		unlink(temporary);
	}
	let command = '/bin/tar -czf ' + shell_quote(output) + ' -C /';
	let paths = component_paths(component);
	let found = 0;
	for (let i = 0; i < length(paths); i++) {
		if (access('/' + paths[i], 'r')) {
			command = command + ' ' + shell_quote(paths[i]);
			found++;
		}
	}
	if (!found) return { ok: false, error: 'Could not create backup: no source files' };
	let result = run_system(command);
	if (result.code != 0) {
		unlink(output);
		return { ok: false, error: 'Could not create backup: system code=' + result.code + ', output=' + result.output };
	}
	return { ok: true, file: filename, component: component };
}

function list_backups() {
	let result = [];
	let p = popen('/bin/ls -1 ' + shell_quote(BACKUP_DIR) + ' 2>/dev/null', 'r');
	if (p == null) return result;
	let text = p.read('all') || '';
	p.close();
	let lines = split(text, '\n');
	for (let i = 0; i < length(lines); i++) {
		let name = lines[i];
		if (!match(name, /^backup-[0-9]+-(mihomo|dns|schedule|magitrickle|routing|all)\.tar\.gz$/)) continue;
		let parts = split(name, '-');
		if (length(parts) != 3) continue;
		push(result, { file: name, created: parts[1], component: replace(parts[2], /\.tar\.gz$/, '') });
	}
	return result;
}

function prune(component, retention) {
	let items = list_backups();
	let selected = [];
	for (let i = 0; i < length(items); i++) if (items[i].component == component) push(selected, items[i]);
	while (length(selected) > retention) {
		let oldest = selected[0];
		for (let i = 1; i < length(selected); i++) if (int(selected[i].created) < int(oldest.created)) oldest = selected[i];
		unlink(BACKUP_DIR + '/' + oldest.file);
		let next = [];
			for (let i = 0; i < length(selected); i++) if (selected[i].file != oldest.file) push(next, selected[i]);
		selected = next;
	}
}

const methods = {
	status: { call: function() { return { ok: true, backups: list_backups(), settings: read_settings() }; } },
	create: { args: { component: 'string' }, call: function(req) {
		try {
			let component = req.args.component || 'all';
			let result = create_backup(component);
			if (result.ok) {
				try {
					prune(component, read_settings().retention);
				} catch (e) {
					result.warning = 'prune exception: ' + e;
				}
			}
			return result;
		} catch (e) {
			return { ok: false, error: 'create exception: ' + e };
		}
	} },
	delete: { args: { file: 'string' }, call: function(req) {
		let file = req.args.file || '';
		if (!match(file, /^backup-[0-9]+-(mihomo|dns|schedule|magitrickle|routing|all)\.tar\.gz$/)) return { ok: false, error: 'Invalid backup file' };
		return { ok: unlink(BACKUP_DIR + '/' + file) };
	} },
	restore: { args: { file: 'string' }, call: function(req) {
		let file = req.args.file || '';
		if (!match(file, /^backup-[0-9]+-(mihomo|dns|schedule|magitrickle|routing|all)\.tar\.gz$/)) return { ok: false, error: 'Invalid backup file' };
		let archive = BACKUP_DIR + '/' + file;
		let command;
		if (match(file, /-all\.tar\.gz$/) != null && access('/sbin/sysupgrade', 'x'))
			command = run_system('/sbin/sysupgrade -q -r ' + shell_quote(archive));
		else
			command = run_system('/bin/tar -xzf ' + shell_quote(archive) + ' -C /');
		if (command.code != 0) return { ok: false, error: 'Could not restore backup: system code=' + command.code + ', output=' + command.output };
		return { ok: true };
	} },
	settings: { args: { retention: 'string', auto_mihomo: true, auto_magitrickle: true }, call: function(req) { return save_settings(req.args); } }
};

return { 'mixomo-backup': methods };
