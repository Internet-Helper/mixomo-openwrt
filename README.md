<div align="center">
  <img src="https://github.com/user-attachments/assets/1f74035d-8be0-4cac-9670-54dbad1ccd56" width="20" alt="Telegram">
  <a href="https://t.me/Inter_net_Helper/8872">Группа в Telegram</a> для вопросов или обсуждения 
</div>

<div align="center">
  <img src="https://github.com/user-attachments/assets/b74aab60-2d5e-40de-a688-0eb3a58cbe11" width="20" alt="Money"> Поблагодарить можно через
  <a href="https://pay.cloudtips.ru/p/8ec8a87c">CloudTips</a> или <a href="https://yoomoney.ru/to/41001945296522">Юмани</a>
</div>
<br>  

<img width="1920" height="478" alt="Logo-2" src="https://github.com/user-attachments/assets/d3ae54a4-5db1-4395-84c7-40600bf1718c" />

## Описание

> [!WARNING]  
> На данный момент проект находится в стадии **альфа** тестирования.  
> Автор не несёт ответственности за порчу оборудования, программного обеспечения и иные возможные проблемы.  
> Сообщить об ошибках или задать вопросы можно в <a href="https://t.me/Inter_net_Helper/8872">группе Telegram</a>

**Mixomo-OpenWrt** - это автоматическая установка трёх компонентов для умной маршрутизации трафика на роутерах OpenWrt:  
- [Mihomo](https://github.com/MetaCubeX/mihomo) - многофункциональное прокси-ядро  
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) - tun <-> socks5 мост (он нужен чтобы Mihomo связать с MagiTrickle)
- [MagiTrickle](https://github.com/MagiTrickle/MagiTrickle) | [MagiTrickle Mod](https://github.com/badigit/MagiTrickle_mod_badigit) - направляет в прокси-ядро Mihomo только выбранные домены и подсети (IP/CIDR)  

**Что это даёт на практике:**
- Через прокси проходит только тот трафик, который Вы в него направили
- Всё остальное идёт через Вашего домашнего провайдера на его полной скорости, минуя прокси‑ядро
- При необходимости можно использовать локальную маршрутизацию, чтобы отправлять весь трафик выбранных IP/CIDR в ядро Mihomo

<img width="1212" height="1414" alt="image" src="https://github.com/user-attachments/assets/0d82becc-37ac-41b8-8420-a3eeb26547a6" />

# Требования
- OpenWrt 24.10+ и 25.12+
- ~16 МБ во Временном хранилище для загрузки архива прокси-ядра Mihomo
- Минимум 18 МБ в Дисковом пространстве для всех необходимых пакетов  

# Установка или обновление  
#### Команда для установки или обновления:
```
curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/install.sh | sh
```
#### Альтернативная команда для установки или обновления:
```
wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/install.sh | sh
```

#### Что сделать после установки?  
- **Крайне желательно** изменить DNS-серверы на публичные [по быстрой инструкции](https://github.com/Internet-Helper/mixomo-openwrt/blob/main/DNS.md)
- Зайти в LuCI -> Службы или Services -> Mihomo -> Создать свою конфигурацию<br>
  Для этого можно использовать [оригинальную документацию](https://mihomo-docs.netlify.app/ru/config/) или [онлайн генератор web4core](https://spatiumstas.github.io/web4core)  
  Конфигурация **обязана** содержать строку `mixed-port: 7890` для работы через hev-socks5-tunnel
- Зайти в LuCI -> Службы или Services -> MagiTrickle -> Указать сайты в «Группы» или ссылки в «Подписки»<br> 

**Некоторые пояснения:**  
- Повторный запуск команды установки переустановит Mihomo, hev-socks5-tunnel и MagiTrickle на актаульные версии  
- Конфигурация Mihomo останется нетронутой только если в ней есть строка `mixed-port: 7890`  
- Конфигурация MagiTrickle останется нетронутой при одинаковых версиях с актуальной, в ином случае Ваша конфигурация сохранится рядом в виде бэкапа
- При нехватке места и наличии Mihomo будет предложено его удалить и продолжить установку, но конфигурация сохраниться только если в ней есть строка `mixed-port: 7890`  
- **Если всё равно не хватило места для обновления** - сохраните конфигурации Mihomo и MagiTrickle, запустите скрипт удаления и заново запустите скрипт установки 

# Установка или обновление тестовой версии  
#### Команда для установки:
```
curl -fsSL -o /tmp/mixomo.sh https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/test-install.sh && sh /tmp/mixomo.sh
```
#### Альтернативная команда для установки:
```
wget -q --no-check-certificate -O /tmp/mixomo.sh https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/test-install.sh && sh /tmp/mixomo.sh
```

# Удаление  
#### Команда для удаления:
```
curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/delete.sh | sh
```
#### Альтернативная команда для удаления:
```
wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/delete.sh | sh
```

# Лицензия

Данный проект распространяется по лицензии [Apache 2.0](https://github.com/Internet-Helper/mixomo-openwrt/blob/main/LICENSE).
