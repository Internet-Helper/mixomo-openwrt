<div align="center">
  <img src="https://github.com/user-attachments/assets/1f74035d-8be0-4cac-9670-54dbad1ccd56" width="20" alt="Telegram">
  <a href="https://t.me/Inter_net_Helper/8872">Группа в Telegram</a> для вопросов или обсуждения 
</div>

<div align="center">
  <img src="https://github.com/user-attachments/assets/b74aab60-2d5e-40de-a688-0eb3a58cbe11" width="20" alt="Money"> Поблагодарить можно через
  <a href="https://pay.cloudtips.ru/p/8ec8a87c">CloudTips</a> или <a href="https://yoomoney.ru/to/41001945296522">Юмани</a>
</div>
<br>  
  
<img width="1920" height="478" alt="Logo" src="https://github.com/user-attachments/assets/c4a4aa90-c9d2-4c82-ac77-7487a4392cdb" />

## Описание

> [!WARNING]  
> На данный момент проект находится в стадии **альфа** тестирования.  
> Автор не несёт ответственности за порчу оборудования, программного обеспечения и иные возможные проблемы.  
> Сообщить об ошибках или задать вопросы можно в <a href="https://t.me/Inter_net_Helper/8872">группе Telegram</a>

**Mixomo-OpenWrt** - это автоматическая установка трёх компонентов для умной маршрутизации трафика на роутерах OpenWrt:  
- [Mihomo](https://github.com/MetaCubeX/mihomo) - многофункциональное прокси-ядро  
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) - быстрый tun <-> socks5 мост (он нужен чтобы Mihomo связать с MagiTrickle)  
- [MagiTrickle](https://github.com/MagiTrickle/MagiTrickle) - направляет в прокси-ядро Mihomo только выбранные домены и подсети (IP/CIDR)  

**Что это даёт на практике:**
- Через прокси проходит только тот трафик, который Вы в него направили
- Всё остальное идёт через Вашего домашнего провайдера на его полной скорости, минуя прокси‑ядро

<img width="1222" height="1544" alt="Windows" src="https://github.com/user-attachments/assets/ce48a2f0-0a7f-4dd9-a2bc-bc4cf4ce0297" />

# Требования
- OpenWrt 24.10+ и 25.12+
- ~16 МБ во Временном хранилище для загрузки архива прокси-ядра Mihomo
- Минимум 18 МБ в Дисковом пространстве для всех необходимых пакетов  

# Установка или обновление  
#### Команда для установки или обновления:
```
wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh | sh
```
#### Альтернативная команда для установки или обновления:
```
curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_install.sh | sh
```

**Некоторые пояснения:**  
- Повторный запуск команды установки переустановит Mihomo, hev-socks5-tunnel и MagiTrickle на актаульные версии  
- Конфигурация Mihomo останется нетронутой только если в ней есть строка *mixed-port: 7890*  
- Конфигурация MagiTrickle останется нетронутой при одинаковых версиях с актуальной, в ином случае Ваша конфигурация сохранится рядом в виде бэкапа
- При нехватке места и наличии Mihomo будет предложено его удалить и продолжить установку, но конфигурация сохраниться только если в ней есть строка *mixed-port: 7890*  
- **Если всё равно не хватило места для обновления** - сохраните конфигурации Mihomo и MagiTrickle, запустите скрипт удаления и заново запустите скрипт установки

#### Что сделать после установки?  
- Зайти в LuCI -> Службы или Services -> Mihomo -> Вставить свою конфигурацию<br>
  Чтобы её составить можно использовать [оригинальную документацию](https://mihomo-docs.netlify.app/ru/config/) или [онлайн генератор web4core](https://spatiumstas.github.io/web4core)  
  Конфигурация **обязана** содержать строку *mixed-port: 7890* для работы через *hev-socks5-tunnel*
- Зайти в LuCI -> Службы или Services -> MagiTrickle -> Создать списки нужных сайтов или указать в виде ссылок в разделе «Подписки»<br>  
- (*Опционально*) Изменить DNS-серверы на публичные -> [ссылка на инструкцию](https://forum.routerich.ru/t/kak-izmenit-dns/71)

# Удаление  
#### Команда для удаления:
```
wget -qO- --no-check-certificate https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh | sh
```
#### Альтернативная команда для удаления:
```
curl -fsSL https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/refs/heads/main/mixomo_openwrt_delete.sh | sh
```
