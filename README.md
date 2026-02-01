<img width="969" height="236" alt="mixomo" src="https://github.com/user-attachments/assets/290fcf0f-a1b8-439e-8b61-fb74fda313ca" />

## Описание
Автоматический установщик Mihomo, hev-socks5-tunnel и MagiTrickle для OpenWRT.  
После установки необходимо лишь настроить конфигурацию Mihomo (рекомендации — здесь) и добавить списки сайтов в MagiTrickle.  
Управление осуществляется через службы в LuCI.

<img width="988" height="908" alt="1" src="https://github.com/user-attachments/assets/621d1a57-9e5f-4427-b5b2-a128abf0f616" />

# Установка
Загрузите необходимые пакеты:
```
opkg update && opkg install curl wget-ssl
```
Команда для установки:
```
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh || wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh)"
```
Альтернативная команда (если не сработала выше):
```
wget -qO /tmp/mixomo_openwrt_install.sh --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh && chmod +x /tmp/mixomo_openwrt_install.sh && /tmp/mixomo_openwrt_install.sh && rm /tmp/mixomo_openwrt_install.sh
```

# Обновление
Скрипт обновит Mihomo, hev-socks5-tunnel и мод MagiTrickle (оригинал пока зафиксирован).  
Ваши настройки Mihomo и списки сайтов MagiTrickle останутся нетронутыми.  
Если появится новая версия конфигурации у MagiTrickle, то старая версия будет сохранена рядом как бэкап.

Команда для обновления:
```
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh || wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh)"
```
Альтернативная команда (если не сработала выше):
```
wget -qO /tmp/mixomo_openwrt_install.sh --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh && chmod +x /tmp/mixomo_openwrt_install.sh && /tmp/mixomo_openwrt_install.sh && rm /tmp/mixomo_openwrt_install.sh
```


# Удаление
Команда для удаления:
```
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh || wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh)"
```
Альтернативная команда (если не сработала выше):
```
wget -qO /tmp/mixomo_openwrt_delete.sh --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh && chmod +x /tmp/mixomo_openwrt_delete.sh && /tmp/mixomo_openwrt_delete.sh && rm /tmp/mixomo_openwrt_delete.sh
```
