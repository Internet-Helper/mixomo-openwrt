# Mixomo OpenWRT
# Описание
Автоматический установщик Mihomo, hev-socks5-tunnel и MagiTrickle для OpenWRT.  
После установки необходимо лишь настроить конфигурацию Mihomo (рекомендации — здесь) и добавить списки сайтов в MagiTrickle.  
Управление осуществляется через службы в LuCI.

# Установка
Загрузите необходимые пакеты:
```
opkg update && opkg install curl wget-ssl
```
Команда для автоматической установки:
```
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh || wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh)"
```
Альтернативная команда (если не сработала выше):
```
wget -qO /tmp/mixomo_openwrt_install.sh --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh && chmod +x /tmp/mixomo_openwrt_install.sh && /tmp/mixomo_openwrt_install.sh && rm /tmp/mixomo_openwrt_install.sh
```

# Удаление
Команда для автоматического удаления:
```
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh || wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh)"
```
Альтернативная команда для удаления (если не сработала выше):
```
wget -qO /tmp/mixomo_openwrt_delete.sh --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh && chmod +x /tmp/mixomo_openwrt_delete.sh && /tmp/mixomo_openwrt_delete.sh && rm /tmp/mixomo_openwrt_delete.sh
```
