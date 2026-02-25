<div align="center">
  <img src="https://github.com/user-attachments/assets/1f74035d-8be0-4cac-9670-54dbad1ccd56" width="20" alt="Telegram">
  <a href="https://t.me/Inter_net_Helper/8872">Группа в Telegram</a> для вопросов или обсуждения 
</div>

<div align="center">
  <img src="https://github.com/user-attachments/assets/b74aab60-2d5e-40de-a688-0eb3a58cbe11" width="20" alt="Money"> Поблагодарить можно через
  <a href="https://pay.cloudtips.ru/p/8ec8a87c">CloudTips</a> или <a href="https://yoomoney.ru/to/41001945296522">Юмани</a>
</div>

<img width="969" height="236" alt="mixomo" src="https://github.com/user-attachments/assets/290fcf0f-a1b8-439e-8b61-fb74fda313ca" />  

## Описание

> [!WARNING]  
> На данный момент проект находится в стадии **альфа** тестирования.  
> Автор не несёт ответственности за порчу оборудования и программного обеспечения, проблемы с доступом.  
> Сообщить об ошибках или задать вопросы можно в <a href="https://t.me/Inter_net_Helper/8872">группе Telegram</a>.

**Mixomo-OpenWRT** - это автоматическая установка трёх компонентов для умной маршрутизации трафика на роутерах OpenWRT:  
- [Mihomo](https://github.com/MetaCubeX/mihomo) - мощный и современный прокси-движок.  
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) - быстрый tun <-> socks5 мост. Нужен чтобы MagiTrickle увидел интерфейс Mihomo.  
- [MagiTrickle](https://github.com/MagiTrickle/MagiTrickle) | [MagiTrickle_Mod](https://github.com/LarinIvan/MagiTrickle_Mod) - направляет в прокси только выбранные домены и подсети (IP/CIDR).

**Что это даёт на практике:**
- Нет падения скорости для всего остального трафика (КиноПоиск, онлайн-игры, обновления Windows и т.д.)  
- Значительно меньшая нагрузка на процессор роутера  
- Экономия лимитного прокси-трафика  
- Торренты, майнинг, P2P и подобный трафик не попадает в прокси, если Вы не добавите соответствующие IP/подсети в MagiTrickle

Управление происходит через удобный веб-интерфейс LuCI в разделах Mihomo и MagiTrickle:

<img width="988" height="908" alt="1" src="https://github.com/user-attachments/assets/621d1a57-9e5f-4427-b5b2-a128abf0f616" />

<img width="993" height="527" alt="image" src="https://github.com/user-attachments/assets/1ae832a5-9bdd-45e8-b229-61fbae029203" />

# Требования
- От OpenWRT 22.03 и до OpenWRT 24+ включительно
- 16 МБ во Временном хранилище для загрузки архива
- 32 МБ в Дисковом пространстве для всех необходимых пакетов

При нехватке места и обнаружении Mihomo будет предложено его удалить и установить заново.  
Конфигурация сохраниться только если там есть строка *mixed-port: 7890*  

# Что делать после установки  
- Зайти в LuCI -> Службы или Services -> Mihomo -> Вставить свою конфигурацию.<br>
  Чтобы её составить можно использовать [оригинальную документацию](https://mihomo-docs.netlify.app/ru/config/) или [онлайн генератор web4core](https://spatiumstas.github.io/web4core).
- Зайти в LuCI -> Службы или Services -> MagiTrickle -> Создать списки доменов или подсетей.<br>  
- (*Опционально*) Изменить DNS-серверы на публичные -> [ссылка на инструкцию](https://forum.routerich.ru/t/kak-izmenit-dns/71).

# Установка и обновление
Если у вас форк OpenWRT (Routerich и т.п.), лучше выбрать **оригинальный** MagiTrickle после начала установки.  

Загрузите необходимые пакеты:
```
opkg update && opkg install curl wget-ssl
```
Команда для установки или обновления:
```
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh || wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh)"
```
Альтернативная команда (если не сработала выше):
```
wget -qO /tmp/mixomo_openwrt_install.sh --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh && chmod +x /tmp/mixomo_openwrt_install.sh && /tmp/mixomo_openwrt_install.sh && rm /tmp/mixomo_openwrt_install.sh
```  
  
Повторный запуск обновит Mihomo, hev-socks5-tunnel и мод MagiTrickle (оригинал пока зафиксирован).  
Ваши настройки Mihomo и списки сайтов MagiTrickle останутся нетронутыми.  
Если появится новая техническая версия конфигурации MagiTrickle, предыдущая будет сохранена рядом в виде бэкапа.

# Удаление
Пакеты `curl` и `wget-ssl` удалены не будут.  

Команда для удаления:
```
/bin/sh -c "$(curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh || wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh)"
```
Альтернативная команда (если не сработала выше):
```
wget -qO /tmp/mixomo_openwrt_delete.sh --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh && chmod +x /tmp/mixomo_openwrt_delete.sh && /tmp/mixomo_openwrt_delete.sh && rm /tmp/mixomo_openwrt_delete.sh
```
