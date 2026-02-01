#!/bin/sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${GREEN}=== $* ===${NC}"; }
log_done()  { echo -e "${GREEN}$*${NC}"; }
step_ok()   { echo -e "${GREEN}[OK]${NC}"; }
step_fail() { echo -e "${RED}[FAIL]${NC}"; exit 1; }

MIHOMO_INSTALL_DIR="/etc/mihomo"
MIHOMO_BIN="/usr/bin/mihomo"

detect_mihomo_arch() {
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64)
            echo "amd64" 
            ;;
        i?86)
            echo "386"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7*)
            echo "armv7"
            ;;
        armv5*|armv4*)
            echo "armv5"
            ;;
        mips)
            echo "mips-softfloat"
            ;;
        mipsle)
            echo "mipsle-softfloat"
            ;;
        mips64)
            echo "mips64"
            ;;
        riscv64)
            echo "riscv64"
            ;;
        *)
            log_error "Архитектура $arch не распознана автоматически."
            exit 1
            ;;
    esac
}

install_mihomo() {
	if ! . /etc/openwrt_release 2>/dev/null || [ "${DISTRIB_RELEASE%%.*}" -lt 22 ]; then
		log_error "Требуется OpenWrt 22.03 или новее"
		return 1
	fi

	local REQ_TMP_KB=16000
	local REQ_ROOT_KB=36000
	local AVAIL_TMP_KB
	AVAIL_TMP_KB=$(df -k /tmp | awk 'NR==2 {print $4}')

	if [ "$AVAIL_TMP_KB" -lt "$REQ_TMP_KB" ]; then
		log_error "Ошибка: недостаточно места в /tmp (RAM) для скачивания архива!"
		log_error "Доступно: $((AVAIL_TMP_KB/1024)) MB, Требуется: $((REQ_TMP_KB/1024)) MB"
		return 1
	fi

	local INSTALL_DIR_PATH
	INSTALL_DIR_PATH=$(dirname "$MIHOMO_BIN")

	local AVAIL_ROOT_KB
	AVAIL_ROOT_KB=$(df -k "$INSTALL_DIR_PATH" | awk 'NR==2 {print $4}')

	if [ "$AVAIL_ROOT_KB" -lt "$REQ_ROOT_KB" ]; then
		log_error "Ошибка: недостаточно места на диске для установки ядра!"
		log_error "Доступно: $((AVAIL_ROOT_KB/1024)) MB, Требуется: $((REQ_ROOT_KB/1024)) MB"
		
		if [ -f "$MIHOMO_BIN" ]; then
			log_warn "Обнаружена установленная версия ядра: $MIHOMO_BIN"
			
			echo -n "Удалить старую версию для освобождения места? [y/+/д или N/-/н]: "
			read -r response
			
			case "$response" in
				[yY+дД]*)
					log_info "Удаление старой версии..."
					rm -f "$MIHOMO_BIN"
					
					AVAIL_ROOT_KB=$(df -k "$INSTALL_DIR_PATH" | awk 'NR==2 {print $4}')
					
					if [ "$AVAIL_ROOT_KB" -lt "$REQ_ROOT_KB" ]; then
						log_error "Место всё равно не хватает после удаления старой версии!"
						log_error "Доступно: $((AVAIL_ROOT_KB/1024)) MB, Требуется: $((REQ_ROOT_KB/1024)) MB"
						log_warn "Удалите другие ненужные пакеты или файлы вручную."
						return 1
					else
						log_info "Места теперь достаточно. Продолжаем установку..."
						log_info "Доступно на диске: $((AVAIL_ROOT_KB/1024)) MB"
					fi
					;;
				*)
					log_warn "Установка отменена пользователем."
					log_warn "Совет: удалите ненужные пакеты или старую версию вручную перед установкой."
					return 1
					;;
			esac
		else
			log_warn "Старая версия не найдена. Удалите ненужные пакеты вручную."
			return 1
		fi
	else
		log_info "Свободного места достаточно для дальнейшей установки."
	fi

    if [ -f "/etc/init.d/mihomo" ]; then
        /etc/init.d/mihomo stop 2>/dev/null || true
    fi

    echo "--> Обновление списков пакетов и установка необходимых зависимостей..."
    
    local PKG_LOG="/tmp/mihomo_install.log"

    if ! opkg update > "$PKG_LOG" 2>&1; then
        log_error "Ошибка при обновлении списков пакетов (opkg update)!"
        cat "$PKG_LOG"
        rm -f "$PKG_LOG"
        step_fail
    fi

    if ! opkg install kmod-nft-tproxy kmod-tun curl libcurl4 ca-bundle wget-ssl ca-certificates > "$PKG_LOG" 2>&1; then
        log_error "Ошибка при установке пакетов!"
        
        if grep -iq "No space left on device" "$PKG_LOG" || grep -iq "write error" "$PKG_LOG"; then
            echo ""
            log_error "Недостаточно места на диске!"
            log_warn "Попробуйте удалить лишние пакеты или сделать сброс роутера."
            echo ""
        else
            cat "$PKG_LOG"
        fi
        
        rm -f "$PKG_LOG"
        step_fail
    fi

    rm -f "$PKG_LOG"

    if [ -z "${MIHOMO_ARCH+x}" ]; then
        MIHOMO_ARCH=$(detect_mihomo_arch)
    fi
    echo "--> Архитектура системы: $(uname -m) -> выбран файл: $MIHOMO_ARCH"

    mkdir -p "$MIHOMO_INSTALL_DIR" \
			 /etc/mihomo/proxy-providers \
			 /etc/mihomo/rule-providers \
             /etc/mihomo/rule-files \
             /etc/mihomo/UI

    echo "--> Получение номера последней версии..."
    RELEASE_TAG=$(curl -Ls -o /dev/null -w '%{url_effective}' https://github.com/MetaCubeX/mihomo/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -z "$RELEASE_TAG" ]; then
        log_error "Не удалось определить версию. Проверьте интернет."
        return 1
    fi
    echo "--> Последняя версия: $RELEASE_TAG"

    FILENAME="mihomo-linux-${MIHOMO_ARCH}-${RELEASE_TAG}.gz"
    DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${RELEASE_TAG}/${FILENAME}"
    TMP_FILE="/tmp/mihomo.gz"

    log_info "Скачивание архива $FILENAME"
    echo "--> URL: $DOWNLOAD_URL"

    if ! curl -Lf --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$TMP_FILE"; then
        log_error "Ошибка скачивания! Проверьте, существует ли файл $FILENAME в релизах."
        return 1
    fi

    echo "--> Распаковка архива..."
    if ! gunzip -c "$TMP_FILE" > "$MIHOMO_BIN" 2>/dev/null; then
        log_error "Ошибка распаковки архива"
        rm -f "$TMP_FILE"
        return 1
    fi

    chmod +x "$MIHOMO_BIN"
    rm -f "$TMP_FILE"

    echo "--> Проверка работы ядра Mihomo..."
    if ! "$MIHOMO_BIN" -v >/dev/null 2>&1; then
        log_error "Ядро скачано, но не запускается! Возможно, выбрана неверная архитектура (например, hardfloat вместо softfloat)."
        return 1
    fi

	chmod +x /usr/bin/mihomo || return 1

	local CONFIG_FILE="/etc/mihomo/config.yaml"
    local WRITE_NEW_CONFIG=1

    if [ -f "$CONFIG_FILE" ]; then
        if grep -q "mixed-port: 7890" "$CONFIG_FILE"; then
            echo "--> Найдена существующая конфигурация с корректным портом (mixed-port: 7890)"
            echo "--> Оставляем текущую конфигурацию без изменений..."
            WRITE_NEW_CONFIG=0
        else
            log_warn "Найдена конфигурация, но в ней нет 'mixed-port: 7890'."
            log_info "Предыдущая конфигурация сохранена в ${CONFIG_FILE}.bak чтобы использовать новую."
            cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        fi
    fi

    if [ "$WRITE_NEW_CONFIG" -eq 1 ]; then
        echo "--> Создание новой конфигурации /etc/mihomo/config.yaml..."
        cat > "$CONFIG_FILE" <<EOF || return 1
mode: rule
ipv6: false
mixed-port: 7890
log-level: error
allow-lan: true
unified-delay: true
tcp-concurrent: true
external-controller: 0.0.0.0:9090
external-ui: ./UI
external-ui-url: "https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip"
routing-mark: 2
profile:
  store-selected: true
  store-fake-ip: true
  tracing: true
sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  sniff:
    HTTP:
      ports: [80]
      override-destination: true
    TLS:
      ports: [443, 8443]
    QUIC:
      ports: [443, 8443]
  skip-domain:
    - Mijia Cloud
    - +.lan
    - +.local
    - +.msftconnecttest.com
    - +.msftncsi.com
    - +.3gppnetwork.org
    - +.openwrt.org
    - +.vsean.net
    - cudy.net

dns:
  enable: true
  listen: 0.0.0.0:7880
  ipv6: false
  prefer-h3: true
  default-nameserver:
    - tls://77.88.8.8
    - tls://8.8.8.8
  proxy-server-nameserver:
    - tls://77.88.8.8
    - tls://8.8.8.8
  direct-nameserver:
    - tls://77.88.8.8
    - tls://8.8.8.8
  nameserver:
    - https://common.dot.dns.yandex.net/dns-query
    - https://dns.google/dns-query

proxies:
  - name: Домашний интернет
    type: direct

proxy-groups:

rule-providers:

rules:
  - MATCH,Домашний интернет
EOF
    fi
	
	echo "--> Создание службы /etc/init.d/mihomo..."
	cat > /etc/init.d/mihomo <<'EOF' || return 1
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

MIHOMO_BIN="/usr/bin/mihomo"
MIHOMO_DIR="/etc/mihomo"
MIHOMO_CONF="/etc/mihomo/config.yaml"

start_service() {
    [ -x "$MIHOMO_BIN" ] || return 1
    [ -s "$MIHOMO_CONF" ] || return 1
    
    procd_open_instance "main"
    procd_set_param command "$MIHOMO_BIN" -d "$MIHOMO_DIR" -f "$MIHOMO_CONF"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger "mihomo"
}
EOF
	chmod +x /etc/init.d/mihomo || return 1

	echo "--> Включение автозапуска Mihomo..."
	/etc/init.d/mihomo enable || log_warn "Не удалось включить автозапуск"

	echo "--> Настройка страницы LuCI для управления Mihomo..."
	mkdir -p /usr/share/luci/menu.d || return 1
	cat > /usr/share/luci/menu.d/luci-app-mihomo.json <<'EOF' || return 1
{
	"admin/services/mihomo": {
		"title": "Mihomo",
		"order": 60,
		"action": { "type": "view", "path": "mihomo/config" },
		"depends": { "acl": [ "luci-app-mihomo" ] }
	}
}
EOF

	mkdir -p /usr/share/rpcd/acl.d || return 1
	cat > /usr/share/rpcd/acl.d/luci-app-mihomo.json <<'EOF' || return 1
{
	"luci-app-mihomo": {
		"description": "Mihomo control",
		"read": {
			"file": {
				"/etc/mihomo/config.yaml": ["read"],
				"/etc/mihomo/rule-files/": ["list"],
				"/etc/mihomo/rule-files/*": ["read"]
			},
			"ubus": {
				"file": ["read", "list"],
				"service": ["list"]
			}
		},
		"write": {
			"file": {
				"/etc/mihomo/config.yaml": ["write"],
				"/etc/mihomo/rule-files/*": ["write"],
				"/usr/bin/mihomo": ["exec"],
				"/etc/init.d/mihomo": ["exec"],
				"/sbin/logread": ["exec"],
				"/bin/sh": ["exec"],
				"/bin/ash": ["exec"],
				"/usr/bin/curl": ["exec"],
				"/usr/bin/wget": ["exec"],
				"/bin/gzip": ["exec"],
				"/bin/chmod": ["exec"],
				"/bin/mv": ["exec"],
				"/bin/rm": ["exec"]
			},
			"ubus": {
				"file": ["write"],
				"service": ["list"]
			}
		}
	}
}
EOF

    local VIEW_PATH="/www/luci-static/resources/view/mihomo"
    local ACE_PATH="$VIEW_PATH/ace"
    
    mkdir -p "$ACE_PATH" || return 1

    echo "--> Определение последней версии ACE Editor..."
    
    local LATEST_ACE_VER
    LATEST_ACE_VER=$(curl -s "https://api.cdnjs.com/libraries/ace" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 | head -1)

    if [ -z "$LATEST_ACE_VER" ]; then
        log_warn "Не удалось получить версию через API, используем фиксированную версию"
        LATEST_ACE_VER="1.43.3"
    else
        echo "--> Последния версия: $LATEST_ACE_VER"
    fi

    log_info  "Скачивание ACE Editor $LATEST_ACE_VER..."
    
    local CDN_BASE="https://cdnjs.cloudflare.com/ajax/libs/ace/${LATEST_ACE_VER}"
    
    for file in ace.min.js theme-merbivore_soft.min.js theme-tomorrow.min.js mode-yaml.min.js worker-yaml.min.js; do
        local target_name=$(echo "$file" | sed 's/\.min\.js$/.js/')
        local dest="${ACE_PATH}/${target_name}"
        
        local attempt=1
        local max_attempts=2
        local success=0

        while [ $attempt -le $max_attempts ]; do
            if ! curl -Lf -s -o "$dest" "${CDN_BASE}/${file}"; then
                if ! wget -q -O "$dest" "${CDN_BASE}/${file}"; then
                    true 
                fi
            fi

            if [ -s "$dest" ]; then
                success=1
                break
            else
                rm -f "$dest"
                if [ $attempt -lt $max_attempts ]; then
                    log_warn "Файл $target_name скачался пустым или возникла ошибка. Повторная попытка..."
                    sleep 1
                fi
            fi
            
            attempt=$((attempt + 1))
        done

        if [ $success -eq 0 ]; then
            log_error "Не удалось скачать $file после $max_attempts попыток."
            return 1
        fi
    done

	echo "--> Создание config.js..."
	cat > "$VIEW_PATH/config.js" <<'EOF' || return 1
'use strict';
'require view';
'require fs';
'require ui';
'require rpc';

var ACE_DIR = '/luci-static/resources/view/mihomo/ace/';
var RELOAD_DELAY = 1000;
var MAIN_CONFIG = '/etc/mihomo/config.yaml';
var RULE_DIR = '/etc/mihomo/rule-files/';

var editor = null;
var currentFile = MAIN_CONFIG;
var cachedRuleFiles = [];
var mainConfigContent = '';
var loadedScripts = {};
var VALID_ACTIONS = ['start', 'stop', 'restart', 'check', 'logs'];

var callServiceList = rpc.declare({
    object: 'service',
    method: 'list',
    params: ['name']
});

function escapeHtml(text) {
    if (typeof text !== 'string') return text;
    return text.replace(/[&<>"']/g, function(m) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m];
    });
}

function validatePath(path, allowedBase) {
    if (!path || typeof path !== 'string') return false;
    if (path.includes('..') || path.includes('\0') || path.includes('~')) return false;
    var resolved = path.replace(/\/+/g, '/');
    if (!resolved.startsWith(allowedBase)) return false;
    if (resolved.length > 1024) return false;
    return true;
}

function isSafeRulePath(path) {
    return validatePath(path, RULE_DIR) && path !== MAIN_CONFIG;
}

function validateFilename(filename) {
    if (!filename || typeof filename !== 'string') return false;
    if (!/^[a-zA-Z0-9._-]+$/.test(filename)) return false;
    if (filename.length > 255) return false;
    var reservedNames = ['con', 'prn', 'aux', 'nul', 'com1', 'lpt1', '.'];
    if (reservedNames.includes(filename.toLowerCase())) return false;
    return true;
}

function sanitizeTabName(name) {
    if (!name) return '';
    return name.replace(/[<>"'`]/g, '');
}

function loadScript(src) {
    return new Promise(function(resolve, reject) {
        if (loadedScripts[src]) { resolve(); return; }
        var script = document.createElement('script');
        script.src = src;
        script.onload = function() { loadedScripts[src] = true; resolve(); };
        script.onerror = reject;
        document.head.appendChild(script);
    });
}

function detectRuleType(line) {
    line = line.trim();
    if (line.includes(':') && !line.match(/http(s)?:\/\//)) return 'IP-CIDR6';
    if (/^\d{1,3}(\.\d{1,3}){3}\/\d+$/.test(line)) return 'IP-CIDR';
    if (/^\d{1,3}(\.\d{1,3}){3}$/.test(line)) return 'IP-CIDR';
    if (line.startsWith('.')) return 'DOMAIN-WILDCARD';
    var cleanDomain = line.replace(/^\./, '');
    var dots = (cleanDomain.match(/\./g) || []).length;
    if (dots >= 2) return 'DOMAIN';
    if (dots === 1) return 'DOMAIN-SUFFIX';
    return 'DOMAIN-KEYWORD';
}

function generateProviderSnippet(filename) {
    if (filename === MAIN_CONFIG) return '';
    var baseName = filename.split('/').pop();
    if (!validateFilename(baseName)) throw new Error('Invalid filename');
    var nameNoExt = baseName.replace(/\.(yaml|txt)$/, '');
    var isTxt = baseName.endsWith('.txt');
    var behavior = isTxt ? 'domain' : 'classical';
    var format = isTxt ? 'text' : 'yaml';
    return `${nameNoExt}-list:\n  type: file\n  behavior: ${behavior}\n  format: ${format}\n  path: ./rule-files/${baseName}`;
}

function isLuciDarkMode() {
    try {
        var rgb = window.getComputedStyle(document.body).backgroundColor.match(/\d+/g);
        if (rgb) {
            var luma = 0.2126 * parseInt(rgb[0]) + 0.7152 * parseInt(rgb[1]) + 0.0722 * parseInt(rgb[2]); 
            return luma < 128;
        }
    } catch(e) {}
    return false;
}

return view.extend({
    isProcessing: false,
    currentVersion: 'Неизвестно',
    latestVersion: null,
    updateButton: null,
    latestVersionEl: null,
	
    getMihomoVersion: function() {
        return fs.stat('/usr/bin/mihomo')
            .then(function() { return fs.exec('/usr/bin/mihomo', ['--v']); })
            .then(function(res) {
                if (res.code === 0 && res.stdout) {
                    var match = res.stdout.match(/v(\d+\.\d+\.\d+)/);
                    return match ? match[0] : 'Неизвестно';
                }
                return 'Неизвестно';
            })
            .catch(function(err) {
                console.error('Error getting version:', err);
                return 'Неизвестно';
            });
    },

    renderUpdateStatus: function(latestVersion, isManual) {
        var currentVersion = this.currentVersion || 'Неизвестно';
        this.latestVersion = latestVersion;

        if (this.latestVersionEl) {
            this.latestVersionEl.textContent = _('[актуальная: %s]').format(latestVersion);
            this.latestVersionEl.style.display = 'inline';
            this.latestVersionEl.style.color = (latestVersion !== currentVersion) ? '#5cb85c' : '#888';
        }

        if (latestVersion === currentVersion) {
            this.updateButton.textContent = _('Проверить обновление');
            this.updateButton.className = 'btn cbi-button-neutral';
            this.updateButton.disabled = false;
            this.updateButton.onclick = function() { window.location.reload(); };
            if (isManual) window.location.reload();
        } else {
            this.updateButton.textContent = _('Установить обновление');
            this.updateButton.className = 'btn cbi-button-action';
            this.updateButton.disabled = false;
            this.updateButton.onclick = ui.createHandlerFn(this, 'handleUpdateMihomo');
        }
    },
	
	checkForUpdates: function(isManual) {
		var self = this;
        var CACHE_KEY = 'mihomo_update_cache';
        var CACHE_TIME = 3600 * 1000;

        if (!isManual) {
            try {
                var cachedRaw = localStorage.getItem(CACHE_KEY);
                if (cachedRaw) {
                    var cached = JSON.parse(cachedRaw);
                    if (cached.version && (Date.now() - cached.timestamp < CACHE_TIME)) {
                        this.renderUpdateStatus(cached.version, false);
                        return;
                    }
                }
            } catch (e) {}
        }
		
		if (isManual) ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Проверка обновлений...'))]);
		
		var cmd = 'wget -q -O - "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" 2>/dev/null | grep -m1 \'"tag_name":\' | sed \'s/.*"\\(v[0-9.]*\\)".*/\\1/\'';
		
		fs.exec('/bin/sh', ['-c', cmd])
			.then(function(res) {
				if (isManual) ui.hideModal();
				if (!res || typeof res !== 'object') throw new Error('Bad response');
				var latestVersion = (res.stdout || '').trim().replace(/["'\s]/g, '');
				if (!latestVersion || !latestVersion.match(/^v\d+\.\d+\.\d+$/)) {
				    if (isManual) ui.addNotification(null, E('p', _('Ошибка: ') + latestVersion), 'error');
				    return;
				}
                try { localStorage.setItem(CACHE_KEY, JSON.stringify({ version: latestVersion, timestamp: Date.now() })); } catch (e) {}
				self.renderUpdateStatus(latestVersion, isManual);
			})
			.catch(function(err) {
				if (isManual) {
				    ui.hideModal();
				    ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error');
				}
			});
	},
	
	handleUpdateMihomo: function() {
		var self = this;
		var latestVersion = this.latestVersion;
		if (!latestVersion) return;
		this.updateButton.textContent = _('Подождите...');
		this.updateButton.disabled = true;
		var arch = 'arm64';
		var downloadUrl = 'https://github.com/MetaCubeX/mihomo/releases/download/' + latestVersion + '/mihomo-linux-' + arch + '-' + latestVersion + '.gz';
		var steps = [
			{ msg: _('Создание бэкапа...'), shell: 'cp -f /usr/bin/mihomo /tmp/mihomo.backup' },
			{ msg: _('Остановка Mihomo...'), shell: '/etc/init.d/mihomo stop' },
			{ msg: _('Скачивание архива %s...').format(latestVersion), shell: 'wget -q -O /tmp/mihomo.gz "' + downloadUrl + '" && test -s /tmp/mihomo.gz' },
			{ msg: _('Распаковка архива...'), shell: '/bin/gzip -d -c /tmp/mihomo.gz > /tmp/mihomo_new 2>/dev/null && test -s /tmp/mihomo_new' },
			{ msg: _('Выдача временных прав...'), shell: '/bin/chmod 755 /tmp/mihomo_new' },
			{ msg: _('Проверка ядра...'), shell: '/tmp/mihomo_new -v 2>&1 || true' },
			{ msg: _('Установка ядра...'), shell: '/bin/mv -f /tmp/mihomo_new /usr/bin/mihomo' },
			{ msg: _('Выдача постоянных прав...'), shell: '/bin/chmod 755 /usr/bin/mihomo' },
			{ msg: _('Запуск Mihomo...'), shell: '/etc/init.d/mihomo start' },
			{ msg: _('Удаление бэкапа...'), shell: 'rm -f /tmp/mihomo.gz /tmp/mihomo.backup' }
		];
		var executeStep = function(index) {
			if (index >= steps.length) {
				self.showOutput(_('Обновлено успешно! Перезагрузка...'), false);
				window.location.reload();
				return Promise.resolve();
			}
			var currentStep = steps[index];
			self.showOutput(currentStep.msg, false);
			return fs.exec('/bin/sh', ['-c', currentStep.shell])
				.then(function(res) {
					if (!res || res.code !== 0) throw new Error('Err: ' + (res ? res.code : 'unknown'));
					return executeStep(index + 1);
				});
		};
		executeStep(0).catch(function(err) {
            if (self.updateButton) {
                self.updateButton.textContent = _('Ошибка. Повторить обновление?');
                self.updateButton.disabled = false;
                self.updateButton.onclick = ui.createHandlerFn(self, 'handleUpdateMihomo');
            }
            self.showOutput(_('Ошибка: %s').format(err.message), true);
            fs.exec('/bin/sh', ['-c', 'cp -f /tmp/mihomo.backup /usr/bin/mihomo && /etc/init.d/mihomo start']).catch(function() {});
        });
	},

	load: function() {
		return Promise.all([
			fs.read(MAIN_CONFIG).catch(function() { return ''; }),
			callServiceList('mihomo').catch(function() { return {}; }),
			fs.list(RULE_DIR).catch(function() { return []; })
		]);
	},
	
    render: function(data) {
		data = data || [];
        mainConfigContent = data[0] || '';
        var serviceInfo = data[1] || {};
        cachedRuleFiles = (data[2] || []).sort(function(a, b) { return a.name.localeCompare(b.name); });
        var isRunning = !!(serviceInfo.mihomo && serviceInfo.mihomo.instances.main.running);
        
        var versionContainer = E('span', { 'id': 'mihomo-version', 'style': 'margin-left: 10px; font-size: 12px; color: #888;' }, _('Загрузка...'));
        var latestVersionEl = E('span', { 'id': 'mihomo-latest-version', 'style': 'margin-left: 4px; font-size: 12px; color: #888; display: none;' }, '');
        this.latestVersionEl = latestVersionEl;
        var updateButton = E('button', { 'id': 'mihomo-update-btn', 'class': 'btn cbi-button-neutral', 'style': 'margin-left: 10px; padding: 0 8px;', 'disabled': true }, _('Проверить обновление'));
        this.updateButton = updateButton;
        
        var statusBadge = isRunning 
            ? E('span', { 'class': 'badge', 'style': 'font-size: 13px; font-weight: bold; padding: 6px 14px; margin-left: 14px; border-radius: 8px; background-color: #5cb85c; color: #F8F8F8;' }, _('работает'))
            : E('span', { 'class': 'badge', 'style': 'font-size: 13px; font-weight: bold; padding: 6px 14px; margin-left: 14px; border-radius: 6px; background-color: #888; color: #F8F8F8;' }, _('остановлен'));
        
        var serviceButton = isRunning
            ? E('button', { 'class': 'btn cbi-button-reset', 'style': 'margin-left: 16px; padding: 0 12px;', 'click': ui.createHandlerFn(this, 'handleServiceAction', 'stop') }, _('Остановить'))
            : E('button', { 'class': 'btn cbi-button-action', 'style': 'margin-left: 16px; padding: 0 12px; border-color: #5cb85c; color: #5cb85c;', 'click': ui.createHandlerFn(this, 'handleServiceAction', 'start') }, _('Запустить'));
        
        var header = E('div', { 'style': 'display: flex; align-items: center; margin-bottom: 16px; flex-wrap: wrap;' }, [
            E('h2', { 'style': 'margin: 0;' }, _('Mihomo')), 
            statusBadge, 
            serviceButton, 
            versionContainer, 
            latestVersionEl,
            updateButton
        ]);
		
        var self = this;
        this.getMihomoVersion().then(function(version) {
            self.currentVersion = version;
            var versionEl = document.getElementById('mihomo-version');
            if (versionEl) versionEl.textContent = _('%s').format(version);
            var updateBtn = document.getElementById('mihomo-update-btn');
            if (updateBtn) {
                updateBtn.disabled = false;
                updateBtn.onclick = function() { self.checkForUpdates(true); }; 
            }
            self.checkForUpdates(false);
        });
        
        var isDark = isLuciDarkMode();
        var cssVariables = isDark ? `
            :root {
                --bg-tab: #2d2d2d;
                --bg-tab-active: #1C1C1C;
                --bg-toolbar: #1C1C1C;
                --bg-input: #2d2d2d;
                --text-main: #e0e0e0;
                --text-dim: #969696;
                --border-color: #444444;
                --border-active: #444444;
                --bg-output: #222222;
                --bg-output-header: #333333;
                --text-output: #f8f8f2;
            }
        ` : `
            :root {
                --bg-tab: #e0e0e0;
                --bg-tab-active: #ffffff;
                --bg-toolbar: #f5f5f5;
                --bg-input: #ffffff;
                --text-main: #333333;
                --text-dim: #666666;
                --border-color: #E0E0E0;
                --border-active: #E0E0E0;
                --bg-output: #ffffff;
                --bg-output-header: #eeeeee;
                --text-output: #333333;
            }
        `;

        var style = E('style', {}, cssVariables + `
            .cbi-page-actions { display: none !important; }
            .custom-actions { display: flex; gap: 8px; }
            .tab-bar { display: flex; flex-wrap: nowrap; background-color: var(--bg-tab); }
            .tab-item { display: flex; align-items: center; padding: 8px 15px; cursor: pointer; background-color: var(--bg-tab); color: var(--text-dim); margin-right: 1px; font-size: 13px; border-top: 1px solid transparent; white-space: nowrap; user-select: none; box-sizing: border-box }
            .tab-item:hover { background-color: var(--bg-toolbar); color: var(--text-main); }
            .tab-item.active { background-color: var(--bg-tab-active); color: var(--text-main); border: 1px solid var(--border-active); }
            .tab-close { margin-left: 8px; border-radius: 3px; padding: 0 4px; color: #999; font-weight: bold; }
            .tab-close:hover { background-color: #c0392b; color: white; }
            .tab-new { font-weight: bold; font-size: 16px; padding: 8px 12px; }
            .toolbar { background-color: var(--bg-toolbar); border: 1px solid var(--border-color); padding: 10px; color: var(--text-main); }
            .toolbar-row { display: flex; gap: 10px; align-items: center; }
            .toolbar textarea { width: 100%; height: 70px; background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 12px; padding: 5px; }
            .toolbar select { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: 5px; }
            .toolbar-col { display: flex; flex-direction: column; }
            .btn-save-custom { border-color: #5cb85c !important; color: #5cb85c !important; }
            .btn-save-custom:hover { border-color: #5cb85c !important; }
            .btn.cbi-button-action:hover { border-color: #5cb85c !important; }
            .btn.cbi-button-reset:hover { border-color: #F62B12 !important; color: #F62B12 !important; }
            .btn-generate { border-color: #5cb85c !important; color: #5cb85c !important; margin: auto 0; display: block; background: var(--bg-input); }
            .btn-generate:hover { border-color: #5cb85c !important; }
            .snippet-container { margin-top: 0; border: 1px solid var(--border-color); background: var(--bg-toolbar); padding: 10px; display: none; }
            .snippet-header { margin-bottom: 5px; color: var(--text-main); font-size: 12px; }
            .snippet-text { width: 100%; height: 115px; background: var(--bg-tab-active); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 12px; padding: 10px; resize: none; }
            .output-box-close { background: transparent; border: none; color: var(--text-main); font-size: 22px; line-height: 1; cursor: pointer; margin-left: 15px; padding: 0 5px; }
            .output-box-close:hover { color: #e74c3c !important; }
			#ace_editor_container { width: 100%; height: 700px; border: 1px solid var(--border-color); border-top: none; }
        `);
        
        var tabBar = E('div', { 'id': 'mihomo-tab-bar', 'class': 'tab-bar' });
        var toolbarContainer = E('div', { 'id': 'mihomo-toolbar' });
        var editorContainer = E('div', { 'id': 'ace_editor_container' });
        
        var snippetContainer = E('div', { 'id': 'snippet-box', 'class': 'snippet-container', 'style': 'margin-top: 10px' }, [
            E('div', { 'class': 'snippet-header', 'style': 'color: var(--text-dim)' }, _('Чтобы Mihomo увидел файл, добавьте эту секцию в rule-providers:')),
            E('textarea', { 'id': 'snippet-area', 'class': 'snippet-text', 'readonly': 'readonly', 'style': 'color: var(--text-dim)' }),
            E('div', { 'style': 'margin-top: 10px; display: flex; gap: 10px;' }, [
                E('button', { 'class': 'btn cbi-button-apply', 'click': ui.createHandlerFn(this, 'handleAutoAddSnippet') }, _('Добавить автоматически')),
                E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleCopySnippet') }, _('Скопировать текст'))
            ])
        ]);
        
        var buttonContainer = E('div', { 'id': 'bottom-buttons', 'class': 'custom-actions', 'style': 'margin-top: 15px;' }, [
            E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleCheck') }, _('Проверить конфигурацию')),
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', 'click': ui.createHandlerFn(this, 'handleSaveAndApply', isRunning) }, _('Сохранить')),
            E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleOpenDashboard', mainConfigContent) }, _('Открыть панель управления')),
            E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleShowLogs') }, _('Показать журнал'))
        ]);
        
        var middleActions = E('div', { 'id': 'middle-actions', 'style': 'display: none; margin-top: 10px;' }, [
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', 'click': ui.createHandlerFn(this, 'handleSaveAndApply', isRunning) }, _('Сохранить'))
        ]);
        
        var outputBox = E('div', { 'id': 'output-box', 'style': 'display: none; margin-top: 20px; border: 1px solid #444; border-radius: 4px; overflow: hidden;' }, [
            E('div', { 'style': 'background: var(--bg-output-header); color: var(--text-output); padding: 8px 12px; border-bottom: 1px solid #444; display: flex; align-items: center;' }, [
                E('strong', {}, _('Вывод:')),
                E('button', { 'class': 'output-box-close', 'click': function() { document.getElementById('output-box').style.display = 'none'; } }, '×')
            ]),
            E('pre', { 'id': 'output-text', 'style': 'margin: 0; padding: 15px; background: var(--bg-output); color: var(--text-output); font-family: monospace; font-size: 12px; white-space: pre-wrap; word-wrap: break-word; max-height: 400px; overflow-y: auto;' }, '')
        ]);
        
        loadScript(ACE_DIR + 'ace.js').then(function() {
            ace.config.set('basePath', ACE_DIR);
            editor = ace.edit("ace_editor_container");
            var theme = isDark ? "ace/theme/merbivore_soft" : "ace/theme/tomorrow";
            editor.setTheme(theme);
            editor.session.setMode("ace/mode/yaml");
            editor.setOptions({ 
				fontSize: "13px", 
				showPrintMargin: false, 
				wrap: true, 
				tabSize: 2, 
				useSoftTabs: true,
				highlightActiveLine: false
			});
            editor.setValue(mainConfigContent, -1);
            setTimeout(function() { editor.resize(); }, 100);
        }).catch(console.error);
        
        this.renderTabBar(tabBar);
        this.renderToolbar(toolbarContainer, MAIN_CONFIG);
        setTimeout(function() { this.updateVisibility(MAIN_CONFIG); }.bind(this), 100);
        
        return E('div', { 'class': 'cbi-map' }, [
            header, style, tabBar, toolbarContainer, editorContainer,
            middleActions, snippetContainer, buttonContainer, outputBox
        ]);
    },
    
    updateVisibility: function(filePath) {
        var isMain = (filePath === MAIN_CONFIG);
        document.getElementById('bottom-buttons').style.display = isMain ? 'flex' : 'none';
        document.getElementById('middle-actions').style.display = isMain ? 'none' : 'block';
        var snippetBox = document.getElementById('snippet-box');
        if (isMain) {
            snippetBox.style.display = 'none';
        } else {
            var baseName = filePath.split('/').pop().replace(/\.(yaml|txt)$/, '');
            var providerName = baseName + '-list:';
            if (mainConfigContent.includes(providerName)) {
                snippetBox.style.display = 'none';
            } else {
                document.getElementById('snippet-area').value = generateProviderSnippet(filePath);
                snippetBox.style.display = 'block';
            }
        }
    },
    
	handleAutoAddSnippet: function() {
		var self = this;
		var snippet = generateProviderSnippet(currentFile);
		if (!snippet) return;
		ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Добавление...'))]);
		var indentedSnippet = snippet.split('\n').map(function(line) { return '  ' + line; }).join('\n');
		fs.read(MAIN_CONFIG).then(function(content) {
			var newContent = content || '';
			var sectionMatch = newContent.match(/^rule-providers:\s*$/m);
			if (!sectionMatch) {
				var proxiesMatch = newContent.match(/^proxies:\s*$/m);
				var pgMatch = newContent.match(/^proxy-groups:\s*$/m);
				var lastIdx = Math.max(proxiesMatch ? proxiesMatch.index + proxiesMatch[0].length : -1, pgMatch ? pgMatch.index + pgMatch[0].length : -1);
				if (lastIdx > -1) {
					var textAfter = newContent.substring(lastIdx);
					var nextMatch = textAfter.match(/\n(?![ \t])[a-z][^:\n]*:/i);
					if (nextMatch) {
						var insIdx = lastIdx + nextMatch.index;
						newContent = newContent.substring(0, insIdx) + '\nrule-providers:\n\n' + indentedSnippet + '\n' + newContent.substring(insIdx);
					} else {
						newContent = newContent.trimEnd() + '\n\nrule-providers:\n\n' + indentedSnippet + '\n';
					}
				} else {
					if (newContent && !newContent.endsWith('\n')) newContent += '\n';
					newContent += '\nrule-providers:\n\n' + indentedSnippet + '\n';
				}
			} else {
				var secEnd = sectionMatch.index + sectionMatch[0].length;
				var textAfter = newContent.substring(secEnd);
				var nextMatch = textAfter.match(/\n(?![ \t])[a-z][^:\n]*:/i);
				if (nextMatch) {
					var insIdx = secEnd + nextMatch.index;
					newContent = newContent.substring(0, insIdx) + '\n' + indentedSnippet + '\n' + newContent.substring(insIdx);
				} else {
					newContent = newContent.substring(0, secEnd).replace(/\n+$/, '\n') + '\n' + indentedSnippet + '\n';
				}
			}
			mainConfigContent = newContent;
			return fs.write(MAIN_CONFIG, newContent);
		}).then(function() {
			self.updateVisibility(currentFile);
			ui.hideModal();
		}).catch(function(err) {
			ui.hideModal();
			ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error');
		});
	},
    
    handleCopySnippet: function() {
        var area = document.getElementById('snippet-area');
        if (area) { area.select(); document.execCommand('copy'); }
    },
    
    renderToolbar: function(container, filePath) {
        L.dom.content(container, []);
        if (filePath === MAIN_CONFIG) { container.style.display = 'none'; return; }
        
        container.style.display = 'block';
        container.className = 'toolbar';
        var self = this;
        
        if (filePath.endsWith('.txt')) {
            var input = E('textarea', { 'placeholder': 'google.com\nyoutube.com' });
            var suffixCheck = E('input', { 'type': 'checkbox', 'id': 'suffixCheck', 'checked': true });
            
			var row = E('div', { 'class': 'toolbar-row' }, [
				E('div', { 'style': 'flex-grow: 1;' }, input),
				E('div', { 'class': 'toolbar-col', 'style': 'min-width: 150px; display: flex; flex-direction: column; justify-content: space-between;' }, [
					E('label', { 'for': 'suffixCheck', 'style': 'align-self: flex-start;' }, [ suffixCheck, ' Дублировать с точкой (.)' ]),
					E('button', { 'class': 'btn btn-generate', 'style': 'align-self: center;', 'click': function() { self.handleAppendList(input.value, suffixCheck.checked); input.value = ''; } }, _('Добавить в список'))
				])
			]);
            container.appendChild(row);
        } else {
            var input = E('textarea', { 'placeholder': 'google.com\n104.28.0.0/16\n*.example.com' });
            var typeSelect = E('select', {}, [
                E('option', { 'value': 'Auto' }, 'Auto'),
                E('option', { 'value': 'DOMAIN-SUFFIX' }, 'DOMAIN-SUFFIX'),
                E('option', { 'value': 'DOMAIN' }, 'DOMAIN'),
                E('option', { 'value': 'DOMAIN-KEYWORD' }, 'DOMAIN-KEYWORD'),
                E('option', { 'value': 'DOMAIN-WILDCARD' }, 'DOMAIN-WILDCARD'),
                E('option', { 'value': 'IP-CIDR' }, 'IP-CIDR'),
                E('option', { 'value': 'IP-CIDR6' }, 'IP-CIDR6')
            ]);
            var row = E('div', { 'class': 'toolbar-row' }, [
                E('div', { 'style': 'flex-grow: 1;' }, input),
                E('div', { 'class': 'toolbar-col' }, [ typeSelect ]),
                E('div', { 'class': 'toolbar-col', 'style': 'min-width: 120px; justify-content: flex-end;' }, [
                    E('button', { 'class': 'btn btn-generate', 'click': function() { self.handleGenerateRules(input.value, typeSelect.value); input.value = ''; } }, _('Сгенерировать'))
                ])
            ]);
            container.appendChild(row);
        }
    },
    
    handleAppendList: function(text, addSuffix) {
        if (!editor || !text.trim()) return;
        var lines = text.trim().split('\n');
        var result = [];
        lines.forEach(function(line) {
            line = line.trim();
            if (!line) return;
            result.push(line);
            if (addSuffix && !line.startsWith('.')) result.push('.' + line);
        });
        if (result.length > 0) {
            editor.navigateFileEnd();
            var doc = editor.getValue();
            var prefix = (doc.length > 0 && !doc.endsWith('\n')) ? '\n' : '';
            editor.insert(prefix + result.join('\n') + '\n');
            editor.focus();
        }
    },
    
    handleGenerateRules: function(text, type) {
        if (!editor || !text.trim()) return;
        var lines = text.trim().split('\n');
        var newRules = [];
        lines.forEach(function(line) {
            line = line.trim();
            if (!line) return;
            var currentType = type === 'Auto' ? detectRuleType(line) : type;
            if (currentType === 'IP-CIDR' && !line.includes('/')) line += '/32';
            newRules.push(`  - ${currentType},${line}`);
        });
        if (newRules.length === 0) return;
        var content = editor.getValue();
        var linesContent = content.split('\n');
        var payloadIndex = linesContent.findIndex(function(l) { return l.trim() === 'payload:'; });
        if (payloadIndex !== -1) {
            editor.gotoLine(linesContent.length + 1, 0);
            editor.insert(newRules.join('\n') + '\n');
        } else {
            var prefix = (content.length > 0 && !content.endsWith('\n')) ? '\n\n' : '';
            editor.navigateFileEnd();
            editor.insert(prefix + 'payload:\n' + newRules.join('\n') + '\n');
        }
        editor.focus();
    },
    
    renderTabBar: function(container) {
        L.dom.content(container, []);
        var self = this;
        var mainTab = E('div', { 'class': (currentFile === MAIN_CONFIG) ? 'tab-item active' : 'tab-item', 'click': ui.createHandlerFn(this, 'handleTabClick', MAIN_CONFIG) }, E('span', {}, 'Конфигурация'));
        container.appendChild(mainTab);
        
        cachedRuleFiles.forEach(function(file) {
            if (file.type === 'file') {
                var fullPath = RULE_DIR + file.name;
                if (!validatePath(fullPath, RULE_DIR)) return;
                var isActive = (currentFile === fullPath);
                var safeName = escapeHtml(sanitizeTabName(file.name));
                var tabContent = [E('span', {}, safeName)];
                if (isActive) {
                    tabContent.push(E('span', { 'class': 'tab-close', 'title': _('Удалить'), 'click': ui.createHandlerFn(self, 'handleDeleteFile', fullPath) }, '×'));
                }
                var tab = E('div', { 'class': isActive ? 'tab-item active' : 'tab-item', 'click': ui.createHandlerFn(self, 'handleTabClick', fullPath) }, tabContent);
                container.appendChild(tab);
            }
        });
        var newTab = E('div', { 'class': 'tab-item tab-new', 'title': _('Создать новый'), 'click': ui.createHandlerFn(this, 'handleCreateFile') }, '+');
        container.appendChild(newTab);
    },
    
    handleTabClick: function(path, ev) {
        if (!validatePath(path, '/etc/mihomo/')) { ui.addNotification(null, E('p', _('Недопустимый путь')), 'error'); return; }
        if (ev && ev.target.classList.contains('tab-close')) { ev.stopPropagation(); return; }
        if (path === currentFile) return;
        
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Загрузка...'))]);
        fs.read(path).then(function(content) {
            currentFile = path;
            if (editor) {
                editor.setValue(content || '', -1);
                editor.session.setMode(path.endsWith('.txt') ? "ace/mode/text" : "ace/mode/yaml");
            }
            self.renderTabBar(document.getElementById('mihomo-tab-bar'));
            self.renderToolbar(document.getElementById('mihomo-toolbar'), path);
            self.updateVisibility(path);
            ui.hideModal();
        }).catch(function(err) {
            if (err && err.message === 'Данные не получены') {
                currentFile = path;
                if (editor) { editor.setValue('', -1); editor.session.setMode(path.endsWith('.txt') ? "ace/mode/text" : "ace/mode/yaml"); }
                self.renderTabBar(document.getElementById('mihomo-tab-bar'));
                self.renderToolbar(document.getElementById('mihomo-toolbar'), path);
                self.updateVisibility(path);
            } else {
                ui.addNotification(null, E('p', _('Ошибка: ') + (err.message || 'Error')), 'error');
            }
            ui.hideModal();
        });
    },
    
    handleCreateFile: function() {
        var self = this;
        var nameInput = E('input', { 'type': 'text', 'style': 'width: 100%;', 'placeholder': 'my-life_my-rules' });
        var typeSelect = E('select', { 'style': 'width: 100%;' }, [
            E('option', { 'value': '.yaml' }, 'Набор правил (.yaml)'),
            E('option', { 'value': '.txt' }, 'Простой список (.txt)')
        ]);
        var footer = E('div', { 'class': 'right', 'style': 'margin-top: 20px;' }, [
            E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Отмена')), ' ',
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', 'click': function() {
                var filename = nameInput.value.trim();
                if (!filename || !validateFilename(filename)) { ui.addNotification(null, E('p', _('Некорректное имя')), 'error'); return; }
                var fullPath = RULE_DIR + filename + typeSelect.value;
                if (!validatePath(fullPath, RULE_DIR)) { ui.addNotification(null, E('p', _('Недопустимый путь')), 'error'); return; }
                ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Создание...'))]);
                fs.stat(fullPath).then(function() {
                    ui.hideModal(); ui.addNotification(null, E('p', _('Файл уже существует')), 'error');
                }).catch(function() {
                    fs.write(fullPath, '').then(function() { return fs.list(RULE_DIR); }).then(function(files) {
                        cachedRuleFiles = (files || []).sort(function(a, b) { return a.name.localeCompare(b.name); });
                        self.handleTabClick(fullPath);
                    }).catch(function(err) { ui.hideModal(); ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
                });
            }}, _('Создать'))
        ]);
        ui.showModal(_('Новый файл правил'), [
            E('div', {}, [
                E('div', { 'style': 'display: flex; align-items: center; margin-bottom: 10px;' }, [ E('label', { 'style': 'min-width: 180px; margin-right: 10px;' }, _('Имя файла:')), nameInput ]),
                E('div', { 'style': 'display: flex; align-items: center;' }, [ E('label', { 'style': 'min-width: 180px; margin-right: 10px;' }, _('Тип файла:')), typeSelect ])
            ]), footer
        ]);
        nameInput.focus();
    },
    
    handleDeleteFile: function(path) {
        if (!isSafeRulePath(path)) { ui.addNotification(null, E('p', _('Ошибка пути')), 'error'); return; }
        if (!confirm(_('Удалить %s?').format(path.split('/').pop()))) return;
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Удаление...'))]);
        fs.remove(path).then(function() { return fs.list(RULE_DIR); }).then(function(files) {
            cachedRuleFiles = (files || []).sort(function(a, b) { return a.name.localeCompare(b.name); });
            if (currentFile === path) self.handleTabClick(MAIN_CONFIG);
            else { self.renderTabBar(document.getElementById('mihomo-tab-bar')); ui.hideModal(); }
        }).catch(function(err) { ui.hideModal(); ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
    },
    
    handleSaveAndApply: function(wasRunning) {
        if (this.isProcessing) return Promise.reject(new Error('Busy'));
        if (!editor) return;
        this.isProcessing = true;
        var self = this;
        var content = editor.getValue();
        if (currentFile === MAIN_CONFIG) mainConfigContent = content;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Сохранение...'))]);
        fs.write(currentFile, content).then(function() {
            if (currentFile === MAIN_CONFIG) {
                return fs.exec('/usr/bin/mihomo', ['-d', '/etc/mihomo', '-t', MAIN_CONFIG]).then(function(res) {
                    if (res.code !== 0) throw new Error((res.stdout || '') + (res.stderr || ''));
                    if (wasRunning) return fs.exec('/etc/init.d/mihomo', ['restart']);
                });
            }
        }).then(function() {
            ui.hideModal();
            if (currentFile === MAIN_CONFIG) setTimeout(function() { window.location.reload(); }, RELOAD_DELAY);
        }).catch(function(err) { self.showOutput(err.message, true); ui.hideModal(); }).finally(function() { self.isProcessing = false; });
    },
    
    handleCheck: function() {
        if (currentFile !== MAIN_CONFIG || !editor) return;
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Проверка...'))]);
        fs.write(MAIN_CONFIG, editor.getValue())
            .then(function() { return fs.exec('/usr/bin/mihomo', ['-d', '/etc/mihomo', '-t']); })
            .then(function(res) { self.showOutput((res.stdout || '') + (res.stderr || ''), res.code !== 0); ui.hideModal(); })
            .catch(function(e) { self.showOutput(e.message, true); ui.hideModal(); });
    },
    
    showOutput: function(text, isError) {
        var box = document.getElementById('output-box');
        var out = document.getElementById('output-text');
        if (box && out) {
            out.textContent = text ? text.trim() : '(Пусто)';
            out.style.color = isError ? '#f92672' : 'var(--text-output)';
            box.style.display = 'block';
            box.scrollIntoView({ behavior: 'smooth', block: 'end' });
        }
    },
    
	handleServiceAction: function(act) {
		if (!VALID_ACTIONS.includes(act)) return;
		var self = this;
		ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Выполнение...'))]);
		fs.exec('/etc/init.d/mihomo', [act]).then(function() { window.location.reload(); })
			.catch(function(e) { ui.hideModal(); ui.addNotification(null, E('p', e.message), 'error'); });
	},
    
    handleShowLogs: function() {
        var self = this;
        fs.exec('/sbin/logread', ['-e', 'mihomo']).then(function(res) {
            var logContent = res.stdout;
            if (!logContent && res.code !== 0) {
                logContent = "Записей о 'mihomo' в системном журнале не найдено.\nВозможно, служба не запущена.";
            } else if (!logContent) {
                logContent = "Журнал пуст.";
            }

            self.showOutput(logContent, false);
        }).catch(function(err) {
            self.showOutput("Ошибка чтения журнала: " + err.message, true);
        });
    },
    
    handleOpenDashboard: function(content) {
        var hostname = window.location.hostname;
        var port = '9090';
        try {
            var match = content.match(/external-controller:\s*([0-9\.]+):(\d+)/);
            if (match && match[1] && match[2]) {
                var extractedIp = match[1].trim();
                if (/^(\d{1,3}\.){3}\d{1,3}$/.test(extractedIp) && extractedIp !== '0.0.0.0') hostname = extractedIp;
                var portNum = parseInt(match[2].trim(), 10);
                if (!isNaN(portNum) && portNum >= 1 && portNum <= 65535) port = match[2].trim();
            }
        } catch (e) {}
        window.open(`http://${hostname}:${port}/ui/`, '_blank');
    }
});
EOF
}

install_hev_tunnel() {
	log_info "Установка hev-socks5-tunnel..."
    opkg install hev-socks5-tunnel > /dev/null 2>&1

    echo "--> Создание конфигурации /etc/hev-socks5-tunnel/main.yml..."
    mkdir -p /etc/hev-socks5-tunnel
    cat <<EOF > /etc/hev-socks5-tunnel/main.yml
tunnel:
  name: Mihomo
  mtu: 8500
  multi-queue: false
  ipv4: 198.18.0.1
  ipv6: 'fc00::1'
socks5:
  port: 7890
  address: 127.0.0.1
  udp: 'udp'
EOF
    chmod 600 /etc/hev-socks5-tunnel/main.yml

    echo "--> Очистка старых настроек сети..."
    uci delete network.Mihomo 2>/dev/null
    uci delete firewall.Mihomo 2>/dev/null
    uci delete firewall.lan_to_Mihomo 2>/dev/null

    echo "--> Настройка UCI-сервиса..."
    uci set hev-socks5-tunnel.config.enabled='1'
    uci set hev-socks5-tunnel.config.configfile='/etc/hev-socks5-tunnel/main.yml'
    uci commit hev-socks5-tunnel
    /etc/init.d/hev-socks5-tunnel restart
    sleep 2

    echo "--> Настройка сетевого интерфейса..."
    uci delete network.Mihomo 2>/dev/null || true
    uci set network.Mihomo=interface
    uci set network.Mihomo.proto='none'
    uci set network.Mihomo.device='Mihomo'
    uci commit network
    /etc/init.d/network reload

    echo "--> Настройка firewall..."
    uci delete firewall.Mihomo 2>/dev/null || true
    uci delete firewall.lan_to_Mihomo 2>/dev/null || true

    uci set firewall.Mihomo=zone
    uci set firewall.Mihomo.name='Mihomo'
    uci set firewall.Mihomo.input='REJECT'
    uci set firewall.Mihomo.output='REJECT'
    uci set firewall.Mihomo.forward='REJECT'
    uci set firewall.Mihomo.masq='1'
    uci set firewall.Mihomo.mtu_fix='1'
    uci add_list firewall.Mihomo.network='Mihomo'

    uci set firewall.lan_to_Mihomo=forwarding
    uci set firewall.lan_to_Mihomo.src='lan'
    uci set firewall.lan_to_Mihomo.dest='Mihomo'

    uci commit firewall
    /etc/init.d/firewall restart
}

install_magitrickle() {
    echo "Выберите версию MagiTrickle для установки:"
    echo "1) Оригинал v0.4.0 (https://magitrickle.dev/docs/welcome/)"
    echo "2) Мод от LarinIvan (https://github.com/LarinIvan/MagiTrickle_Mod/)"
    printf "-> "
    read -r CHOICE
    
    echo "--> Подготовка к установке MagiTrickle..."
    
    local CONFIG_PATH="/etc/magitrickle/state/config.yaml"
    local BACKUP_PATH="/tmp/magitrickle_config_backup.yaml"
    
    if [ -f "$CONFIG_PATH" ]; then
        cp "$CONFIG_PATH" "$BACKUP_PATH"
    fi
    
    if opkg list-installed magitrickle_mod >/dev/null 2>&1; then
        opkg remove magitrickle_mod >/dev/null 2>&1
    fi
    if opkg list-installed magitrickle >/dev/null 2>&1; then
        opkg remove magitrickle >/dev/null 2>&1
    fi
    
    case "$CHOICE" in
        1)
            ARCH_SYS=$(grep "OPENWRT_ARCH" /etc/os-release | awk -F '"' '{print $2}')
            [ -n "$ARCH_SYS" ] || { log_error "Не удалось определить архитектуру OpenWrt"; return 1; }
            echo "--> Архитектура: $ARCH_SYS"
            IPK="magitrickle_0.4.0-1_openwrt_${ARCH_SYS}.ipk"
            URL="https://gitlab.com/api/v4/projects/69165954/packages/generic/magitrickle/0.4.0/$IPK"
            cd /tmp
            wget -O "$IPK" "$URL" || { log_error "Ошибка скачивания оригинального MagiTrickle"; return 1; }
            opkg install "$IPK" || return 1
            rm -f "$IPK"
            echo "--> Включение автозапуска MagiTrickle..."
            /etc/init.d/magitrickle enable >/dev/null 2>&1
            echo "--> Запуск MagiTrickle..."
            /etc/init.d/magitrickle start >/dev/null 2>&1
            ;;
        2)
            log_info "Установка MagiTrickle_Mod..."
            wget -O- https://raw.githubusercontent.com/LarinIvan/MagiTrickle_Mod/develop/add_repo.sh | sh || return 1
            ;;
        *)
            log_error "Неверный выбор"
            return 1
            ;;
    esac
    
    compare_versions() {
        local v1="$1"
        local v2="$2"
        
        local IFS='.'
        set -- $v1
        local v1_major="$1" v1_minor="$2" v1_patch="$3"
        set -- $v2
        local v2_major="$1" v2_minor="$2" v2_patch="$3"
        
        v1_major="${v1_major:-0}"
        v1_minor="${v1_minor:-0}"
        v1_patch="${v1_patch:-0}"
        v2_major="${v2_major:-0}"
        v2_minor="${v2_minor:-0}"
        v2_patch="${v2_patch:-0}"
        
        if [ "$v1_major" -gt "$v2_major" ]; then
            return 1
        elif [ "$v1_major" -lt "$v2_major" ]; then
            return 2
        fi
        
        if [ "$v1_minor" -gt "$v2_minor" ]; then
            return 1
        elif [ "$v1_minor" -lt "$v2_minor" ]; then
            return 2
        fi
        
        if [ "$v1_patch" -gt "$v2_patch" ]; then
            return 1
        elif [ "$v1_patch" -lt "$v2_patch" ]; then
            return 2
        fi
        
        return 0
    }
    
    if [ -f "$BACKUP_PATH" ] && [ -f "$CONFIG_PATH" ]; then
        echo "--> Проверка версии конфигурации..."
        
        OLD_VERSION=$(grep "^configVersion:" "$BACKUP_PATH" | awk '{print $2}' | tr -d ' ')
        NEW_VERSION=$(grep "^configVersion:" "$CONFIG_PATH" | awk '{print $2}' | tr -d ' ')
        
        if [ -z "$OLD_VERSION" ] || [ -z "$NEW_VERSION" ]; then
            log_warn "Не удалось определить версию конфигурации. Бэкап сохранен рядом."
            cp "$BACKUP_PATH" "${CONFIG_PATH}.backup"
            rm -f "$BACKUP_PATH"
        else
            compare_versions "$OLD_VERSION" "$NEW_VERSION"
            local result=$?
            
            case $result in
                0)  echo "--> Версии конфигурации совпадают ($OLD_VERSION). Восстанавление..."
                    cp "$BACKUP_PATH" "$CONFIG_PATH"
                    rm -f "$BACKUP_PATH"
                    ;;
                1)  log_warn "Версия старой конфигурации ($OLD_VERSION) выше новой ($NEW_VERSION)! Бэкап сохранен рядом."
                    cp "$BACKUP_PATH" "${CONFIG_PATH}.backup"
                    rm -f "$BACKUP_PATH"
                    ;;
                2)  log_info "Новая версия конфигурации ($NEW_VERSION) выше старой ($OLD_VERSION). Бэкап сохранен рядом."
                    cp "$BACKUP_PATH" "${CONFIG_PATH}.backup"
                    rm -f "$BACKUP_PATH"
                    ;;
            esac
        fi
    elif [ -f "$BACKUP_PATH" ]; then
        log_warn "Новая конфигурация не найдена. Восстанавление из бэкапа..."
        mkdir -p "$(dirname "$CONFIG_PATH")"
        cp "$BACKUP_PATH" "$CONFIG_PATH"
        rm -f "$BACKUP_PATH"
    fi
    
    echo "--> Создание страницы MagiTrickle в LuCI..."
    mkdir -p /www/luci-static/resources/view/magitrickle
cat << 'EOF' > /www/luci-static/resources/view/magitrickle/magitrickle.js
'use strict';
'require view';
return view.extend({
    handleSaveApply: null,
    handleSave: null,
    handleReset: null,
    render: function() {
        var ip = window.location.hostname;
        var url = 'http://' + ip + ':8080';
        return E('div', {
            style: 'width:100%; height:92vh; margin: -20px -20px 0 -20px; overflow: hidden;'
        }, E('iframe', {
            src: url,
            style: 'width:100%; height:100%; border: none;'
        }));
    }
});
EOF
cat << 'EOF' > /usr/share/luci/menu.d/luci-app-magitrickle.json
{
    "admin/services/magitrickle": {
        "title": "MagiTrickle",
        "order": 60,
        "action": {
            "type": "view",
            "path": "magitrickle/magitrickle"
        }
    }
}
EOF
}

finalize_install() {
    echo "--> Выставление необходимых прав доступа..."
    chmod -R 755 /www/luci-static/resources/view/mihomo 2>/dev/null || true
    find /www/luci-static/resources/view/mihomo -type f -exec chmod 644 {} \; 2>/dev/null || true
    chmod 644 /www/luci-static/resources/view/magitrickle/magitrickle.js

    echo "--> Очистка кэша LuCI и перезапуск сервисов..."
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
    /etc/init.d/rpcd restart > /dev/null 2>&1
    /etc/init.d/uhttpd restart > /dev/null 2>&1
}

main() {
	clear
    log_done "Скрипт установки Mixomo OpenWRT от Internet Helper"
	echo ""
	
    log_step "[1/3] Установка Mihomo"
    install_mihomo || step_fail
	echo ""
	
    log_step "[2/3] Установка Hev-Socks5-Tunnel"
    install_hev_tunnel || step_fail
	echo ""
	
    log_step "[3/3] Установка MagiTrickle"
    install_magitrickle || step_fail
    finalize_install || step_fail
	echo ""
	
	log_step "Установка прошла успешно!"
	echo ""
	echo "Теперь:"
	echo "1. Выйдите из LuCI (страница роутера) и войдите снова."
	echo "2. Во вкладке «Services\Службы» - «Mihomo» настройте конфигурацию."
	echo "[Совет] https://spatiumstas.github.io/web4core/"
	echo "3. Во вкладке «Services\Службы» - «MagiTrickle» создайте список нужных адресов."
	echo "4. Наслаждайтесь интернетом :)"
	echo ""
}

main