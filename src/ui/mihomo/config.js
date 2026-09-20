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
var currentConfigFile = MAIN_CONFIG;
var currentRuleFile = '';
var editorRequested = false;
var cachedRuleFiles = [];
var mainConfigContent = '';
var loadedScripts = {};
var VALID_ACTIONS = ['start', 'stop', 'restart', 'check', 'logs'];

var MIXOMO_EN = {
    '(доступна новая версия %s)': '(new version %s available)',
    'Файл /etc/dnsmasq.conf будет полностью очищен, останутся только ваши правила.': 'The /etc/dnsmasq.conf file will be completely cleared; only your rules will remain.',
    'DNS-серверы': 'DNS servers',
    'Распаковка архива...': 'Extracting archive...',
    'Режим использования DNS': 'DNS usage mode',
    'Редактировать': 'Edit',
    'Редактировать исключение': 'Edit exclusion',
    'Редактировать правило': 'Edit rule',
    'Ручное редактирование': 'Manual editing',
    'Включено': 'Enabled',
    'Включить': 'Enable',
    'Включить исходящий трафик этого устройства через Mihomo?': 'Route this devices outbound traffic through Mihomo?',
    'Вниз': 'Down',
    'Введите название': 'Enter a name',
    'Вверх': 'Up',
    'Выберите устройство...': 'Select a device...',
    'Выдача постоянных прав...': 'Setting permanent permissions...',
    'Выдача временных прав...': 'Setting temporary permissions...',
    'Отключить исходящий трафик этого устройства через Mihomo?': 'Disable this devices outbound traffic via Mihomo?',
    'Выполнение...': 'Running...',
    'Вывод:': 'Output:',
    'Действие': 'Action',
    'Добавление...': 'Adding...',
    'Добавлять устройства и подсети можно только из локальных диапазонов.': 'Devices and subnets can only be added from local ranges.',
    'Добавить': 'Add',
    'Добавить автоматически': 'Add automatically',
    'Добавить адрес': 'Add address',
    'Добавить DNS-сервер': 'Add DNS server',
    'Добавить правило': 'Add rule',
    'Дополнительное подтверждение': 'Additional confirmation',
    'Локальная маршрутизация': 'Local routing',
    'Файл уже существует': 'File already exists',
    'Чтобы Mihomo увидел файл, добавьте эту секцию в rule-providers:': 'For Mihomo to see the file, add this section to rule-providers:',
    'Или укажите самостоятельно:': 'Or specify manually:',
    'Имя файла:': 'File name:',
    'Исключённые адреса': 'Excluded addresses',
    'Адрес': 'Address',
    'Адрес (IP или CIDR)': 'Address (IP or CIDR)',
    'Адреса': 'Addresses',
    'Адресов пока нет.': 'No addresses yet.',
    'Расписания пока нет.': 'No schedules yet.',
    'Системный': 'System',
    'Ручной': 'Manual',
    'Первый': 'First',
    'Второй': 'Second',
    'Третий': 'Third',
    'Четвёртый': 'Fourth',
    'Пятый': 'Fifth',
    'Шестой': 'Sixth',
    'Седьмой': 'Seventh',
    'Восьмой': 'Eighth',
    'Девятый': 'Ninth',
    'Десятый': 'Tenth',
    'остановлен': 'stopped',
    'Установлена самая актуальная версия': 'The latest version is installed',
    'Удаление бэкапа...': 'Deleting backup...',
    'Удаление...': 'Deleting...',
    'Удалить': 'Delete',
    'Удалить %s?': 'Delete %s?',
    'Удалить правила DNS Mixomo из dnsmasq?': 'Delete Mixomo DNS rules from dnsmasq?',
    'Удалить это правило?': 'Delete this rule?',
    'Удалить этот адрес?': 'Delete this address?',
     'Установить обновление': 'Install update',
     'Установка обновления...': 'Installing update...',
     'Установлена самая актуальная версия': 'The latest version is installed',
     'Доступно обновление MagiTrickle': 'MagiTrickle update available',
     'Авто': 'Auto',
     'Русский': 'Russian',
     'English': 'English',
     'MagiTrickle обновлён': 'MagiTrickle updated',
     'Mixomo обновлён': 'Mixomo updated',
     'Доступно обновление Mixomo': 'Mixomo update available',
     'Ошибка обновления Mixomo': 'Mixomo update error',
     'Ошибка проверки обновлений Mixomo': 'Mixomo update check error',
     'Переключить Mixomo на канал %s?': 'Switch Mixomo to the %s channel?',
     'Превышено время ожидания операции Mixomo': 'Timed out waiting for Mixomo operation',
     'Не удалось скачать установщик Mixomo': 'Could not download Mixomo installer',
     'Не удалось установить Mixomo': 'Could not install Mixomo',
     'Не удалось определить версию Mixomo': 'Could not determine Mixomo version',
     'Версия Mixomo': 'Mixomo version',
     'Mixomo обновлён. Перезагрузить страницу?': 'Mixomo was updated. Reload the page?',
     'Не удалось прочитать версию Mixomo': 'Could not read Mixomo version',
     'Не удалось получить актуальную версию Mixomo': 'Could not get the latest Mixomo version',
     'Не удалось определить SHA bundle Mixomo': 'Could not determine Mixomo bundle SHA',
     'Не удалось выполнить операцию Mixomo': 'Could not perform Mixomo operation',
     'Не удалось дождаться переустановки MagiTrickle': 'Timed out waiting for MagiTrickle reinstall',
     'Установка ядра...': 'Installing the core...',
    'Название': 'Name',
    'Название (необязательно)': 'Name (optional)',
    'Направлять исходящий трафик этого устройства через Mihomo': "Route this device's outgoing traffic through Mihomo",
    'Настройки': 'Settings',
    'Не удалось получить состояние DNS': 'Could not get DNS status',
    'Не удалось применить правило': 'Could not apply the rule',
     'Не удалось применить профиль': 'Could not apply the profile',
    'Недопустимый путь': 'Invalid path',
    'Некорректное имя': 'Invalid name',
    'Некорректный DNS: укажите IPv4 с октетами не длиннее 3 цифр (например 8.8.8.8 или 127.0.0.1#7880)': 'Invalid DNS: provide an IPv4 with octets no longer than 3 digits (e.g. 8.8.8.8 or 127.0.0.1#7880)',
    'Ничего не выбрано. Удалить все правила DNS из dnsmasq?': 'Nothing selected. Delete all DNS rules from dnsmasq?',
    'Новый файл правил': 'New rules file',
    'Закрепить локальные IP за конкретными устройствами можно в ': 'You can pin local IPs to specific devices in ',
    'Запуск Mihomo...': 'Starting Mihomo...',
    'Запустить': 'Start',
    'Загрузка...': 'Loading...',
    'Обновлено успешно! Перезагрузка...': 'Updated successfully! Reloading...',
    'Блокировать QUIC (UDP/443)': 'Block QUIC (UDP/443)',
    'Отключено': 'Disabled',
    'Отключить': 'Disable',
    'Открыть панель управления': 'Open dashboard',
    'Отмена': 'Cancel',
    'Отменить': 'Cancel',
    'Ошибка DNS: ': 'DNS error: ',
    'Ошибка RPC': 'RPC error',
    'Ошибка пути': 'Path error',
    'Ошибка маршрутизации: ': 'Routing error: ',
    'Ошибка. Повторить обновление?': 'Error. Retry the update?',
    'Ошибка: ': 'Error: ',
    'Ошибка: %s': 'Error: %s',
    'Очистить /etc/dnsmasq.conf перед применением': 'Clear /etc/dnsmasq.conf before applying',
    'Через Mihomo': 'Via Mihomo',
    'Мимо Mihomo': 'Bypass Mihomo',
    'Дополнительно': 'Advanced',
    'Остановить': 'Stop',
    'Остановка Mihomo...': 'Stopping Mihomo...',
    'Такое название уже есть среди пресетов': 'This name already exists among the presets',
    'Текст помещается между маркерами # Rules from Mixomo и # End rules from Mixomo. В ручном режиме ничего не генерируется автоматически.': 'The text is placed between the # Rules from Mixomo and # End rules from Mixomo markers. In manual mode nothing is generated automatically.',
    'Тип подключения': 'Connection type',
    'Тип файла:': 'File type:',
    'Скачивание архива %s...': 'Downloading archive %s...',
    'Скопировать текст': 'Copy text',
    'Сначала выберите устройство': 'First select a device',
    'Создание бэкапа...': 'Creating backup...',
    'Создание...': 'Creating...',
    'Создать': 'Create',
    'Создать новый': 'Create new',
    'Сохранение...': 'Saving...',
    'Сохранить': 'Save',
    'Стандартный': 'Standard',
    'Статических арендах DHCP': 'DHCP static leases',
    'Статус': 'Status',
    'По порядку': 'In order',
    'Обязательный режим для использования секции DNS в Mihomo': 'Required mode for using the DNS section in Mihomo',
    'Автоматический выбор самого быстрого сервера.': 'Automatically picks the fastest server.',
    'Запрос ко всем серверам сразу, ответ от самого первого.': 'Queries all servers at once, using the very first response.',
    'Заменит правила из «Простого режима», если они там есть, на указанные вами ниже.': "Will replace the rules from “Simple Mode”, if they exist there, with the ones you specify below.",
    'Набор правил (.yaml)': 'Rules set (.yaml)',
    'Простой список (.txt)': 'Plain list (.txt)',
    '(Пусто)': '(Empty)',
    'Журнал пуст.': 'Log is empty.',
    'Ошибка чтения журнала: ': 'Error reading log: ',
    "Записей о 'mihomo' в системном журнале не найдено.\nВозможно, служба не запущена.": "No 'mihomo' records found in the system log.\nThe service may not be running.",
    'Конфигурация': 'Configuration',
    'Конфигурации': 'Configs',
    'Списки правил': 'Rules lists',
    'Добавить конфигурацию': 'Add configuration',
    'Добавить список правил': 'Add rules list',
    'Создать конфигурацию': 'Create configuration',
     'Создать список правил': 'Create rules list',
     'Все компоненты': 'All components',
     'Автоматическое копирование перед обновлением': 'Automatic backup before update',
     'Максимальное количество копий для каждого компонента: ': 'Number of copies for each component: ',
     'Импортировать': 'Import',
    'Источник': 'Source',
     'Обновлять': 'Update every',
     'Обновление': 'Update',
     'Каждый': 'Every',
     'Каждые': 'Every',
     'Без обновлений': 'No updates',
     'Свой интервал в часах': 'Custom interval in hours',
     'час': 'hour',
     'часа': 'hours',
     'часов': 'hours',
    'никогда': 'never',
    'ч': 'h',
    'Обновить': 'Refresh',
    '(активный)': '(active)',
    'Импорт...': 'Importing...',
    'Обновление...': 'Refreshing...',
    'Выберите хотя бы одну секцию': 'Select at least one section',
    'Укажите ссылку или выберите файл': 'Provide a link or choose a file',
    'Не удалось получить профили': 'Could not get profiles',
     'Расписание': 'Schedule',
     'Все расписание': 'All schedules',
     'Создать расписание': 'Create schedule',
     'По триггеру и времени': 'By trigger and time',
     'Автоматическое переключение конфигурации по времени или по триггеру.': 'Automatic configuration switching by time or trigger.',
    'Профиль по умолчанию': 'Default profile',
    'По времени': 'By time',
    'По триггеру': 'By trigger',
    'Все дни': 'All days',
    'День %s': 'Day %s',
    'Вс': 'Sun',
    'Пн': 'Mon',
    'Вт': 'Tue',
    'Ср': 'Wed',
    'Чт': 'Thu',
    'Пт': 'Fri',
    'Сб': 'Sat',
     'день': 'day',
     'дня': 'days',
     'дней': 'days',
     'ссылка': 'link',
     'ссылки': 'links',
     'ссылок': 'links',
    'URL-адреса для проверки (через пробел), основной и фолбэк-профили.': 'URLs to check (space separated), primary and fallback profiles.',
    'Проверять каждые, мин': 'Check every, min',
     'Порог сбоев': 'Failure threshold',
     'Расписание создано': 'Schedule created',
     'Через Mihomo': 'Through Mihomo',
     'Напрямую': 'Direct',
     'Основной профиль': 'Primary profile',
    'Фолбэк': 'Fallback',
    'Интервал, мин': 'Interval, min',
    'Редактировать расписание': 'Edit schedule',
    'С': 'From',
    'По': 'To',
    'URL-адреса': 'URLs',
    'Выберите профиль': 'Select a profile',
    'Укажите хотя бы один URL': 'Provide at least one URL',
    'Не удалось получить расписание': 'Could not get the schedule',
    'Все конфигурации': 'All configs',
    'Все списки': 'All lists',
    'Добавленные адреса': 'Added addresses',
    'Профиль': 'Profile',
    'Время': 'Time',
    'Дни': 'Days',
    'Проверка': 'Check',
    'Выбрать время (в часах)': 'Choose time (hours)',
    'Интервал от 1 до 8760 часов': 'Interval from 1 to 8760 hours',
    'Ссылка': 'Link',
    'Открыть в редакторе': 'Open in editor',
    'Редактировать список правил': 'Edit rules list',
    'Конфигурация создана. Для просмотра нажмите «Все конфигурации».': 'Configuration created. Click "All configs" to view.',
    'Список правил создан. Для просмотра нажмите «Все списки».': 'Rules list created. Click "All lists" to view.',
    'Скрыть': 'Hide',
    'Закрыть': 'Close',
    'Локальная конфигурация': 'Local configuration',
    'Онлайн конфигурация': 'Online configuration',
    'Сохранить следующие блоки:': 'Save the following blocks:',
    'Выберите файл': 'Choose a file',
    'Укажите ссылку': 'Provide a link',
    '[активно]': '[active]',
    'Загрузить файл': 'Upload file',
    'Формат списка': 'List format',
     'Локальный список правил': 'Local rules list',
     'Онлайн список правил': 'Online rules list',
     'Локально': 'Local',
     'Онлайн': 'Online',
     'Необязательные опции': 'Optional settings',
     'Необязательно': 'Optional',
     'Имя config зарезервировано Mihomo': 'The name config is reserved by Mihomo',
     'Изменить данные': 'Edit details',
     'Открыть в редакторе': 'Open in editor',
     'Локальная конфигурация': 'Local configuration',
     'Название расписания': 'Schedule name',
     'URL для проверки (можно несколько через пробел)': 'Check URL (multiple separated by spaces)',
     'Профиль при наличии связи': 'Profile when connected',
     'Профиль при отсутствии связи': 'Profile when disconnected',
     'Профиль во время расписания': 'Profile during schedule',
     'Ссылки для проверки (можно указать несколько через пробел)': 'Links to check (multiple separated by spaces)',
     'Активный профиль при успешной загрузке ссылок': 'Active profile when links load successfully',
     'Активный профиль при отсутствии загрузки ссылок': 'Active profile when links fail to load',
     'Частота проверки в минутах': 'Check frequency in minutes',
     'Частота повторной проверки при первом сбое в минутах': 'Retry frequency after first failure in minutes',
     'Частота проверки во время сбоев в минутах': 'Failure check frequency in minutes',
     'IP': 'IP',
     'Ручной ввод': 'Manual input',
     'Название': 'Name',
     'Адрес': 'Address',
     'IP (можно указать несколько через пробел)': 'IP (multiple separated by spaces)',
     'Добавить DNS': 'Add DNS',
     'Добавление IP или CIDR': 'Add IP or CIDR',
     'Список IP или CIDR': 'IP or CIDR list',
     'Добавление DNS-сервера': 'Add DNS server',
     'Список DNS-серверов': 'DNS server list',
     'Панель управления': 'Dashboard',
     'IP или CIDR (ручной ввод)': 'IP or CIDR (manual)',
     'Автоматический IP': 'Automatic IP',
     'Ручной ввод IP или CIDR': 'Manual IP or CIDR input',
     'Автоматический': 'Automatic',
     'Ручной ввод': 'Manual input',
     'По времени и триггеру': 'By time and trigger',
     'Понедельник': 'Monday',
     'Вторник': 'Tuesday',
     'Среда': 'Wednesday',
     'Четверг': 'Thursday',
     'Пятница': 'Friday',
     'Суббота': 'Saturday',

    'Скопировать активную конфигурацию': 'Copy the active configuration',
    'Перетащить': 'Drag',
    'Трафик к этим адресам никогда не направляется через Mihomo.': 'Traffic to these addresses is never routed through Mihomo.',
    'Параллельный': 'Parallel',
    'По умолчанию добавлены следующие подсети, без возможности их удалить:': 'The following subnets are added by default, without the ability to remove them:',
    'Подождите...': 'Please wait...',
    'Ожидайте...': 'Please wait...',
    'Подтверждение': 'Confirmation',
    'Показать журнал': 'Show log',
    'Списков правил пока нет.': 'No rules lists yet.',
    'При добавлении абсолютно весь трафик устройств направляется через Mihomo': 'When added, all traffic from these devices is routed through Mihomo',
    'При применении они будут удалены.': 'They will be removed when applied.',
    'Применение...': 'Applying...',
    'Применить': 'Apply',
    'Все устройства переходят на TCP вместо UDP (QUIC) на 443 порту, что упрощает маршрутизацию в Mihomo.': 'All devices switch to TCP instead of UDP (QUIC) on port 443, which simplifies routing in Mihomo.',
    'Применяется только к исходящим соединениям этого устройства — apk update, opkg update, wget, curl и тому подобное.': "Applies only to this device's outgoing connections - apk update, opkg update, wget, curl and the like.",
    'Продолжить': 'Continue',
    'Проверить конфигурацию': 'Check configuration',
    'Проверить обновление': 'Check for update',
    'Проверка обновлений...': 'Checking for updates...',
    'Проверка ядра...': 'Checking the core...',
    'Проверка...': 'Checking...',
    'Простое редактирование': 'Simple editing',
    'Простое добавление': 'Simple add',
    'Ручное добавление': 'Manual add',
    'работает': 'running',
    'DNS-сервер создан': 'DNS server created',
    'IP или CIDR': 'IP or CIDR',
    'Автоматическое копирование': 'Automatic backup',
    'Активная конфигурация Mihomo': 'Active Mihomo configuration',
    'Восстановить': 'Restore',
    'Восстановить выбранную резервную копию?': 'Restore the selected backup?',
    'Время начала': 'Start time',
    'Время окончания': 'End time',
    'Все списки правил': 'All rules lists',
    'Выберите хотя бы один компонент': 'Select at least one component',
    'Выйти': 'Exit',
    'Выключено': 'Disabled',
    'Дни недели': 'Weekdays',
    'Копия восстановлена. Перезапустите службы при необходимости.': 'Backup restored. Restart services if needed.',
    'Маршрутизация': 'Routing',
    'Не удалось восстановить копию': 'Could not restore the backup',
    'Не удалось выполнить операцию MagiTrickle': 'Could not perform the MagiTrickle operation',
    'Не удалось найти архив Prerelease-Alpha': 'Could not find the Prerelease-Alpha archive',
    'Не удалось нормализовать конфигурацию': 'Could not normalize the configuration',
    'Не удалось определить архитектуру роутера': 'Could not detect the router architecture',
    'Не удалось определить доступную версию MagiTrickle': 'Could not determine the available MagiTrickle version',
    'Не удалось переключить вариант MagiTrickle': 'Could not switch the MagiTrickle variant',
    'Не удалось переключиться на вариант Mod': 'Could not switch to the Mod variant',
    'Не удалось переключиться на вариант Original': 'Could not switch to the Original variant',
    'Не удалось получить версию MagiTrickle': 'Could not get the MagiTrickle version',
    'Не удалось получить резервные копии': 'Could not get the backups',
    'Не удалось получить состояние': 'Could not get the status',
    'Не удалось создать автоматическую копию': 'Could not create the automatic backup',
    'Не удалось создать копию': 'Could not create the backup',
    'Не удалось сохранить настройки': 'Could not save the settings',
    'Не удалось сохранить порядок DNS': 'Could not save the DNS order',
    'Не удалось удалить копию': 'Could not delete the backup',
    'Неизвестно': 'Unknown',
    'Обзор': 'Overview',
    'Остановлен': 'Stopped',
    'Открыть': 'Open',
    'Очистить и применить': 'Clear and apply',
    'Ошибка обновления MagiTrickle': 'MagiTrickle update error',
    'Ошибка установки MagiTrickle': 'MagiTrickle installation error',
    'Переключить Mihomo на канал %s и установить его версию?': 'Switch Mihomo to the %s channel and install its version?',
    'Переключить вариант MagiTrickle? Компонент будет переустановлен.': 'Switch the MagiTrickle variant? The component will be reinstalled.',
    'Правил пока нет.': 'No rules yet.',
    'Превышено время ожидания операции MagiTrickle': 'MagiTrickle operation timed out',
    'Прикрепить IP к устройству можно в ': 'You can pin an IP to a device in ',
    'Работает': 'Running',
    'Редактирование файла /etc/dnsmasq.conf': 'Editing /etc/dnsmasq.conf',
'Резервное копирование': 'Backup',
     'Ручное копирование': 'Manual backup',
     'Резервных копий пока нет.': 'No backups yet.',
    'Создать копию': 'Create backup',
    'Сохранённые копии': 'Saved backups',
    'Тип конфигурации': 'Configuration type',
    'Укажите IP или CIDR': 'Specify an IP or CIDR',
    'Формат': 'Format',
    'активное расписание': 'active schedule',
    'активных расписания': 'active schedules',
    'активных расписаний': 'active schedules',
    'список': 'list',
    'списка': 'lists',
    'списков': 'lists',
    'активный клиент': 'active client',
    'активных клиента': 'active clients',
    'активных клиентов': 'active clients',
    'активный сервер': 'active server',
    'активных сервера': 'active servers',
    'активных серверов': 'active servers'
};

function detectLuciLang() {
    var lang = '';
    if (window.LANG) {
        lang = window.LANG;
    } else if (document.documentElement && document.documentElement.lang) {
        lang = document.documentElement.lang;
    }
    return (lang || 'ru').toLowerCase();
}

var MIXOMO_LANGUAGE = 'auto';
try {
    var savedMixomoLanguage = localStorage.getItem('mixomo_language');
    if (savedMixomoLanguage === 'ru' || savedMixomoLanguage === 'en') MIXOMO_LANGUAGE = savedMixomoLanguage;
} catch (e) {}
var MIXOMO_IS_EN = MIXOMO_LANGUAGE === 'en' || (MIXOMO_LANGUAGE === 'auto' && /^en/.test(detectLuciLang()));

(function() {
    var orig = window._;
    window._ = function(text) {
        if (text === 'Dismiss' || text === 'Отклонить') {
            return MIXOMO_IS_EN ? 'Close' : 'Закрыть';
        }
        if (MIXOMO_IS_EN && MIXOMO_EN.hasOwnProperty(text)) {
            return MIXOMO_EN[text];
        }
        if (orig) {
            return orig.apply(window, arguments);
        }
        return text;
    };
})();

function trError(text) {
    if (!text || typeof text !== 'string' || !MIXOMO_IS_EN) {
        return text;
    }
    if (MIXOMO_EN.hasOwnProperty(text)) {
        return MIXOMO_EN[text];
    }
    if (/^Недопустимый DNS: /.test(text)) {
        return 'Invalid DNS: ' + text.replace(/^Недопустимый DNS: /, '');
    }
    if (/^Октет IP не длиннее 3 цифр: /.test(text)) {
        return 'IP octet no longer than 3 digits: ' + text.replace(/^Октет IP не длиннее 3 цифр: /, '');
    }
    return text;
}


var callServiceList = rpc.declare({
    object: 'service',
    method: 'list',
    params: ['name']
});

var callRoutingStatus = rpc.declare({ object: 'mihomo-routing', method: 'status', expect: { '': {} } });
var callRoutingClients = rpc.declare({ object: 'mihomo-routing', method: 'clients', expect: { '': {} } });
var callRoutingAdd = rpc.declare({ object: 'mihomo-routing', method: 'add', params: ['source', 'label', 'backend'], expect: { '': {} } });
var callRoutingUpdate = rpc.declare({ object: 'mihomo-routing', method: 'update', params: ['id', 'source', 'label', 'backend'], expect: { '': {} } });
var callRoutingDelete = rpc.declare({ object: 'mihomo-routing', method: 'delete', params: ['id'], expect: { '': {} } });
var callRoutingEnabled = rpc.declare({ object: 'mihomo-routing', method: 'set_enabled', params: ['id', 'enabled'], expect: { '': {} } });
var callRoutingRouter = rpc.declare({ object: 'mihomo-routing', method: 'set_router', params: ['enabled'], expect: { '': {} } });
var callRoutingUdp443 = rpc.declare({ object: 'mihomo-routing', method: 'set_udp443', params: ['enabled'], expect: { '': {} } });
var callRoutingExcludeAdd = rpc.declare({ object: 'mihomo-routing', method: 'exclude_add', params: ['dest', 'label'], expect: { '': {} } });
var callRoutingExcludeDelete = rpc.declare({ object: 'mihomo-routing', method: 'exclude_delete', params: ['id'], expect: { '': {} } });
var callRoutingExcludeUpdate = rpc.declare({ object: 'mihomo-routing', method: 'exclude_update', params: ['id', 'dest', 'label'], expect: { '': {} } });
var callRoutingExcludeEnabled = rpc.declare({ object: 'mihomo-routing', method: 'exclude_set_enabled', params: ['id', 'enabled'], expect: { '': {} } });
var callRoutingReorder = rpc.declare({ object: 'mihomo-routing', method: 'reorder', params: ['type', 'order'], expect: { '': {} } });
var callDnsStatus = rpc.declare({ object: 'mihomo-dns', method: 'status', expect: { '': {} } });
var callDnsSetOrder = rpc.declare({ object: 'mihomo-dns', method: 'set_order', params: ['names'], expect: { '': {} } });
var callDnsRenamePreset = rpc.declare({ object: 'mihomo-dns', method: 'rename_preset', params: ['old_name', 'name', 'value'], expect: { '': {} } });
var callDnsApply = rpc.declare({ object: 'mihomo-dns', method: 'apply', params: ['block', 'clean'], expect: { '': {} } });
var callDnsApplyFull = rpc.declare({ object: 'mihomo-dns', method: 'apply_full', params: ['config'], expect: { '': {} } });
var callDnsClear = rpc.declare({ object: 'mihomo-dns', method: 'clear', expect: { '': {} } });
var callDnsAddPreset = rpc.declare({ object: 'mihomo-dns', method: 'add_preset', params: ['name', 'value'], expect: { '': {} } });
var callDnsRemovePreset = rpc.declare({ object: 'mihomo-dns', method: 'remove_preset', params: ['name'], expect: { '': {} } });
var callProfilesList = rpc.declare({ object: 'mihomo-profiles', method: 'list', expect: { '': {} } });
var callProfilesApply = rpc.declare({ object: 'mihomo-profiles', method: 'apply', params: ['name'], expect: { '': {} } });
var callProfilesNormalize = rpc.declare({ object: 'mihomo-profiles', method: 'normalize', params: ['path'], expect: { '': {} } });
var callProfilesImport = rpc.declare({ object: 'mihomo-profiles', method: 'import', params: ['name', 'url', 'content', 'sections', 'interval'], expect: { '': {} } });
var callProfilesCreate = rpc.declare({ object: 'mihomo-profiles', method: 'create', params: ['name', 'copyActive'], expect: { '': {} } });
var callProfilesDelete = rpc.declare({ object: 'mihomo-profiles', method: 'delete', params: ['name'], expect: { '': {} } });
var callRulesImport = rpc.declare({ object: 'mihomo-profiles', method: 'rule_import', params: ['name', 'url', 'content', 'ext', 'interval'], expect: { '': {} } });
var callRulesDelete = rpc.declare({ object: 'mihomo-profiles', method: 'rule_delete', params: ['name'], expect: { '': {} } });
var callRefreshSource = rpc.declare({ object: 'mihomo-profiles', method: 'refresh', params: ['type', 'name'], expect: { '': {} } });
var callSetInterval = rpc.declare({ object: 'mihomo-profiles', method: 'set_interval', params: ['type', 'name', 'interval'], expect: { '': {} } });
var callSetUrl = rpc.declare({ object: 'mihomo-profiles', method: 'set_url', params: ['type', 'name', 'url', 'interval'], expect: { '': {} } });
var callSetOrder = rpc.declare({ object: 'mihomo-profiles', method: 'set_order', params: ['list', 'names'], expect: { '': {} } });
var callProfilesImportFull = rpc.declare({ object: 'mihomo-profiles', method: 'import_full', params: ['name', 'url', 'content'], expect: { '': {} } });
var callProfilesRename = rpc.declare({ object: 'mihomo-profiles', method: 'rename_profile', params: ['old', 'new'], expect: { '': {} } });
var callRulesRename = rpc.declare({ object: 'mihomo-profiles', method: 'rule_rename', params: ['old', 'new', 'ext'], expect: { '': {} } });
var callScheduleList = rpc.declare({ object: 'mihomo-schedule', method: 'list', expect: { '': {} } });
var callScheduleDefault = rpc.declare({ object: 'mihomo-schedule', method: 'default', params: ['profile'], expect: { '': {} } });
var callScheduleSave = rpc.declare({ object: 'mihomo-schedule', method: 'save', params: ['type', 'name', 'enabled', 'profile', 'start', 'end', 'days', 'dom', 'months', 'urls', 'interval', 'fallback', 'primary', 'threshold', 'old', 'mode'], expect: { '': {} } });
var makeScheduleCheckMode = function(value) {
    var mode = value === 'mihomo' ? 'mihomo' : 'direct';
    var box = E('div', { class: 'mihomo-seg' });
    var direct = E('button', { type: 'button', class: 'btn cbi-button-neutral' + (mode === 'direct' ? ' active' : ''), click: function() { box.value = 'direct'; direct.classList.add('active'); mihomo.classList.remove('active'); } }, _('Напрямую'));
    var mihomo = E('button', { type: 'button', class: 'btn cbi-button-neutral' + (mode === 'mihomo' ? ' active' : ''), click: function() { box.value = 'mihomo'; mihomo.classList.add('active'); direct.classList.remove('active'); } }, _('Через Mihomo'));
    box.value = mode;
    box.appendChild(direct);
    box.appendChild(mihomo);
    return box;
};
var makeRoutingBackend = function(value, redirAvail) {
    var mode = value === 'redir-tproxy' && redirAvail ? 'redir-tproxy' : 'tun-socks5';
    var box = E('div', { class: 'mihomo-seg' });
    var redir = E('button', { type: 'button', class: 'btn ' + (mode === 'redir-tproxy' ? 'cbi-button-positive' : 'cbi-button-neutral') + ' mihomo-route-choice' + (mode === 'redir-tproxy' ? ' active' : ''), click: function() { box.value = 'redir-tproxy'; redir.classList.add('active', 'cbi-button-positive'); redir.classList.remove('cbi-button-neutral'); tun.classList.remove('active', 'cbi-button-positive'); tun.classList.add('cbi-button-neutral'); } }, 'Redir-TProxy');
    var tun = E('button', { type: 'button', class: 'btn ' + (mode === 'tun-socks5' ? 'cbi-button-positive' : 'cbi-button-neutral') + ' mihomo-route-choice' + (mode === 'tun-socks5' ? ' active' : ''), click: function() { box.value = 'tun-socks5'; tun.classList.add('active', 'cbi-button-positive'); tun.classList.remove('cbi-button-neutral'); redir.classList.remove('active', 'cbi-button-positive'); redir.classList.add('cbi-button-neutral'); } }, 'Tun-Socks5');
    box.value = mode;
    if (redirAvail) box.appendChild(redir);
    box.appendChild(tun);
    return box;
};
var callScheduleDelete = rpc.declare({ object: 'mihomo-schedule', method: 'delete', params: ['type', 'name'], expect: { '': {} } });
var callScheduleSetEnabled = rpc.declare({ object: 'mihomo-schedule', method: 'set_enabled', params: ['type', 'name', 'enabled'], expect: { '': {} } });
var callBackupStatus = rpc.declare({ object: 'mixomo-backup', method: 'status', expect: { '': {} } });
var callBackupCreate = rpc.declare({ object: 'mixomo-backup', method: 'create', params: ['component'], expect: { '': {} } });
var callBackupDelete = rpc.declare({ object: 'mixomo-backup', method: 'delete', params: ['file'], expect: { '': {} } });
var callBackupRestore = rpc.declare({ object: 'mixomo-backup', method: 'restore', params: ['file'], expect: { '': {} } });
var callBackupSettings = rpc.declare({ object: 'mixomo-backup', method: 'settings', params: ['retention', 'auto_mihomo', 'auto_magitrickle'], expect: { '': {} } });

function escapeHtml(text) {
    if (typeof text !== 'string') return text;
    return text.replace(/[&<>"']/g, function(m) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m];
    });
}

var MIHOMO_DASHBOARDS = {
    zashboard: {
        label: 'Zashboard',
        externalUi: './UI/zashboard/',
        externalUiUrl: 'https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip'
    },
    metacubex: {
        label: 'MetaCube',
        externalUi: './UI/metacubex/',
        externalUiUrl: 'https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz'
    }
};

function getMihomoDashboardSettings(panel) {
    return MIHOMO_DASHBOARDS[panel] || null;
}

function applyMihomoDefaults(content, panel) {
    var settings = getMihomoDashboardSettings(panel);
    var lines = [
        'mixed-port: 7890',
        'redir-port: 5001'
    ];
    if (settings) {
        lines.unshift(
            'external-controller: 0.0.0.0:9090',
            'external-ui: ' + settings.externalUi,
            'external-ui-url: "' + settings.externalUiUrl + '"'
        );
    }
    var keys = /^(external-controller|external-ui|external-ui-url|mixed-port|redir-port|routing-mark)[ \t]*:/;
    var result = String(content || '').replace(/\r\n/g, '\n').replace(/\\n/g, '\n').split('\n').filter(function(line) { return !keys.test(line); }).join('\n');
    result = result.replace(/(^|\n)([^\n]*?)(?=(external-controller|external-ui|external-ui-url|mixed-port|redir-port|routing-mark)[ \t]*:)/g, '$1$2\n');
    result = result.replace(/^(mode:[^\n]*?)(ipv6:)/m, '$1\n$2').replace(/^\n+/, '');
    return lines.join('\n') + '\n' + result;
}

function isEnabledValue(value) {
    return value === true || value === 1 || value === '1' || value === 'true' || value === 'on';
}

function backendLabel(backend) {
    return (backend === 'redir-tproxy') ? 'Redir-TProxy' : 'Tun-Socks5';
}

function displaySource(source) {
    if (typeof source === 'string' && /\/32$/.test(source)) return source.slice(0, -3);
    return source || '';
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

function isConfigPath(path) {
    return path === MAIN_CONFIG || (path.indexOf('/etc/mihomo/profiles/') === 0 && path.endsWith('.yaml'));
}

function normalizeEditorConfig(path) {
    if (!isConfigPath(path)) return Promise.resolve();
    return callProfilesNormalize(path).then(function(res) {
        if (!res || !res.ok) throw new Error((res && res.error) || _('Не удалось нормализовать конфигурацию'));
        return fs.read(path).then(function(content) {
            if (editor && path === currentFile) editor.setValue(content || '', -1);
            if (path === MAIN_CONFIG) mainConfigContent = content || '';
        });
    });
}

function validateFilename(filename) {
    if (!filename || typeof filename !== 'string') return false;
    if (!/^[a-zA-Z0-9._-]+$/.test(filename)) return false;
    if (filename.length > 255) return false;
    var reservedNames = ['con', 'prn', 'aux', 'nul', 'com1', 'lpt1', '.'];
    if (reservedNames.includes(filename.toLowerCase())) return false;
    return true;
}

function isValidDnsValue(value) {
    if (!value || typeof value !== 'string') return false;
    var values = value.trim().split(/\s+/);
    return values.every(function(item) {
        if (!/^[0-9A-Za-z.#:\-@]+$/.test(item)) return false;
        var ip = item.split('#')[0];
        var parts = ip.split('.');
        if (parts.length !== 4) return false;
        for (var i = 0; i < parts.length; i++) {
            if (!/^\d{1,3}$/.test(parts[i])) return false;
        }
        return true;
    });
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
    if (line.startsWith('^')) return 'DOMAIN-REGEX';
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

function makeLuciTab(label, active, onclick) {
    return E('li', { class: active ? '' : 'cbi-tab-disabled' }, E('a', { href: '#', click: function(ev) { ev.preventDefault(); onclick(); } }, label));
}

function isMagiRunningOutput(res) {
    var out = ((res && res.stdout) || '') + '\n' + ((res && res.stderr) || '');
    if (/not\s+running/i.test(out)) return false;
    if (/\binactive\b/i.test(out)) return false;
    if (/\bstopped\b/i.test(out)) return false;
    if (/running/i.test(out)) return true;
    var lines = out.split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        if (/^\s*\d[\d\s]*$/.test(lines[i]) && /\d/.test(lines[i])) return true;
    }
    return false;
}

var MAGI_STATUS_CMD = 'service magitrickle status 2>&1; pidof magitrickled 2>/dev/null; true';

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
    currentVersion: 'Загрузка...',
    latestVersion: null,
    mihomoChannel: 'release',
    mihomoChannelSelect: null,
    updateButton: null,
    latestVersionEl: null,
    routingPanel: null,
    dnsPanel: null,
    overviewPanel: null,
    activeView: 'overview',
    activeSub: 'list',
    subRowVisible: false,
    viewVisible: false,
    dragSource: null,
    configsOrderArr: null,
    rulesOrderArr: null,
    selectFirstRuleOnOpen: false,
    schedTimeOrderArr: null,
    schedTriggerOrderArr: null,
     profilesData: null,
     statusRefreshTimer: null,
     schedulePanel: null,
     scheduleData: null,
     magitrickleVersion: '',
     magitrickleRunning: false,
      magitrickleUpdateButton: null,
      magitrickleVariantSelect: null,
      magitrickleTargetVariant: null,
      magitrickleBusy: false,
      magitricklePanel: null,
      backupPanel: null,
     backupData: null,
     backupSettings: null,
     thirdRow: null,
     activeThird: 'list',
     activeFourth: 'time',
     fourthRow: null,
     dnsModeRow: null,
     dnsMode: 'simple',
     dnsModeVisible: true,
     dnsUsageMode: 'standard',
    dnsChecks: {},
    dnsData: null,
    dnsManualText: '',
     dnsClean: false,
     dnsCustomName: '',
     dnsCustomValue: '',
     dnsOrder: [],
     dnsRefreshToken: 0,


    showRoutingError: function(result) {
        if (!result || !result.ok) ui.addNotification(null, E('p', (result && trError(result.error)) || _('Не удалось применить правило')), 'error');
        return result && result.ok;
    },

    confirmRouterRouting: function(enable) {
        var self = this;
        var text = enable
            ? _('Включить исходящий трафик этого устройства через Mihomo?')
            : _('Отключить исходящий трафик этого устройства через Mihomo?');
        ui.showModal(_('Дополнительное подтверждение'), [
            E('p', {}, text),
            E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отменить')), ' ',
                E('button', { class: 'btn cbi-button-positive', click: function() {
                    ui.hideModal();
                    callRoutingRouter(enable).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); });
                }}, _('Продолжить'))
            ])
        ]);
    },

    setUdp443: function(enabled) {
        var self = this;
        callRoutingUdp443(enabled).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); });
    },

    openRoutingCardEdit: function(cardEl, rule) {
        var self = this;
        var actions = cardEl.querySelector('.mihomo-overview-card-actions');
        if (!actions || cardEl.querySelector('.mihomo-config-card-edit')) return;
        var clients = (this.clientData && this.clientData.clients) || [];
        var redirAvail = !!(this.routingData && (this.routingData.redirAvailable === true || this.routingData.redirAvailable === 1 || this.routingData.redirAvailable === '1'));
        actions.style.display = 'none';
        var head = cardEl.querySelector('.mihomo-overview-card-head');
        var details = cardEl.querySelectorAll('.mihomo-overview-card-detail');
        if (head) head.style.display = 'none';
        for (var di = 0; di < details.length; di++) details[di].style.display = 'none';
        var field = function(label, input) { return E('div', { style: 'margin:.35rem 0;' }, [E('label', { style: 'display:block; opacity:.8; margin-bottom:.15rem;' }, label), input]); };
        var nameInput = E('input', { type: 'text', value: rule.label || '', style: 'width:100%; box-sizing:border-box;' });
        var known = E('select', { style: 'width:100%; box-sizing:border-box;' }, [E('option', { value: '' }, _('Выберите устройство...'))].concat(clients.map(function(c) {
            return E('option', { value: c.ip }, (c.name ? c.name + ' — ' : '') + c.ip);
        })));
        var manual = E('input', { type: 'text', value: '', style: 'width:100%; box-sizing:border-box;' });
        var isDevice = clients.some(function(c) { return c.ip === rule.source; });
        var routeMode = isDevice ? 'auto' : 'manual';
        if (isDevice) known.value = rule.source;
        else manual.value = displaySource(rule.source);
        var autoBox = E('div', { style: 'display:flex; flex-direction:column;' }, [known]);
        var manualBox = E('div', { style: 'display:none; flex-direction:column;' }, [manual]);
        autoBox.style.display = isDevice ? 'flex' : 'none';
        manualBox.style.display = isDevice ? 'none' : 'flex';
        var autoBtn, manualBtn;
        autoBtn = E('button', { class: 'btn ' + (isDevice ? 'cbi-button-positive' : 'cbi-button-neutral') + ' mihomo-route-choice' + (isDevice ? ' active' : ''), click: function() { routeMode = 'auto'; autoBtn.classList.add('active', 'cbi-button-positive'); autoBtn.classList.remove('cbi-button-neutral'); manualBtn.classList.remove('active', 'cbi-button-positive'); manualBtn.classList.add('cbi-button-neutral'); autoBox.style.display = 'flex'; manualBox.style.display = 'none'; } }, _('Системный'));
        manualBtn = E('button', { class: 'btn ' + (!isDevice ? 'cbi-button-positive' : 'cbi-button-neutral') + ' mihomo-route-choice' + (isDevice ? '' : ' active'), click: function() { routeMode = 'manual'; manualBtn.classList.add('active', 'cbi-button-positive'); manualBtn.classList.remove('cbi-button-neutral'); autoBtn.classList.remove('active', 'cbi-button-positive'); autoBtn.classList.add('cbi-button-neutral'); manualBox.style.display = 'flex'; autoBox.style.display = 'none'; } }, _('Ручной'));
         var backend = makeRoutingBackend(rule.backend, redirAvail);
        var edit = E('div', { class: 'mihomo-config-card-edit', style: 'margin-top:.8rem;' }, [
             field(_('Название (необязательно)'), nameInput),
             field(_('Тип подключения'), backend),
             field(_('IP или CIDR'), E('div', {}, [E('div', { class: 'mihomo-seg', style: 'margin:.4rem 0;' }, [autoBtn, manualBtn]), autoBox, manualBox])),
            E('div', { style: 'display:flex; gap:.5rem; margin-top:.6rem;' }, [
                E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action', click: function() {
                    var source, label;
                    if (routeMode === 'manual') {
                        source = manual.value.trim();
                        if (!source) { ui.addNotification(null, E('p', _('Укажите IP или CIDR')), 'error'); return; }
                        label = nameInput.value.trim();
                    } else {
                        if (!known.value) { ui.addNotification(null, E('p', _('Сначала выберите устройство')), 'error'); return; }
                        source = known.value;
                        var selected = clients.filter(function(c) { return c.ip === known.value; })[0];
                        label = nameInput.value.trim() || (selected && selected.name) || '';
                    }
                    callRoutingUpdate(rule.id, source, label, backend.value).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); });
                } }, _('Сохранить')),
                E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { edit.remove(); actions.style.display = 'flex'; if (head) head.style.display = ''; for (var i = 0; i < details.length; i++) details[i].style.display = ''; } }, _('Закрыть'))
            ])
        ]);
        cardEl.insertBefore(edit, actions);
    },

    openExclusionCardEdit: function(cardEl, ex) {
        var self = this;
        var actions = cardEl.querySelector('.mihomo-overview-card-actions');
        if (!actions || cardEl.querySelector('.mihomo-config-card-edit')) return;
        actions.style.display = 'none';
        var head = cardEl.querySelector('.mihomo-overview-card-head');
        var details = cardEl.querySelectorAll('.mihomo-overview-card-detail');
        if (head) head.style.display = 'none';
        for (var di = 0; di < details.length; di++) details[di].style.display = 'none';
        var field = function(label, input) { return E('div', { style: 'margin:.35rem 0;' }, [E('label', { style: 'display:block; opacity:.8; margin-bottom:.15rem;' }, label), input]); };
        var nameInput = E('input', { type: 'text', value: ex.label || '', style: 'width:100%; box-sizing:border-box;' });
        var dest = E('input', { type: 'text', value: displaySource(ex.dest), style: 'width:100%; box-sizing:border-box;' });
        var edit = E('div', { class: 'mihomo-config-card-edit', style: 'margin-top:.8rem;' }, [
            field(_('Название (необязательно)'), nameInput),
            field(_('IP или CIDR'), dest),
            E('div', { style: 'display:flex; gap:.5rem; margin-top:.6rem;' }, [
                E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action', click: function() {
                    if (!dest.value.trim()) { ui.addNotification(null, E('p', _('Укажите IP или CIDR')), 'error'); return; }
                    callRoutingExcludeUpdate(ex.id, dest.value.trim(), nameInput.value.trim()).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                } }, _('Сохранить')),
                E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { edit.remove(); actions.style.display = 'flex'; if (head) head.style.display = ''; for (var i = 0; i < details.length; i++) details[i].style.display = ''; } }, _('Закрыть'))
            ])
        ]);
        cardEl.insertBefore(edit, actions);
    },

    handleReorder: function(type, ids) {
        var self = this;
        return callRoutingReorder(type, ids.join(',')).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
    },

    refreshRouting: function() {
        var self = this;
        return Promise.all([callRoutingStatus(), callRoutingClients()]).then(function(data) {
            self.routingData = data[0] || {}; self.clientData = data[1] || {};
            self.renderRoutingPanel();
        }).catch(function(err) { ui.addNotification(null, E('p', _('Ошибка маршрутизации: ') + err.message), 'error'); });
    },

    getOverviewOrder: function() {
        var defaultOrder = ['magitrickle', 'mihomo', 'schedule', 'profile', 'rules', 'routing', 'dns', 'backup'];
        try {
            var saved = JSON.parse(localStorage.getItem('mihomo_overview_order') || 'null');
            if (Array.isArray(saved) && saved.length === defaultOrder.length && defaultOrder.every(function(id) { return saved.indexOf(id) >= 0; })) return saved;
        } catch (e) {}
        return defaultOrder;
    },

    moveOverviewCard: function(source, target) {
        if (!source || !target || source === target) return;
        var order = this.getOverviewOrder();
        var from = order.indexOf(source), to = order.indexOf(target);
        if (from < 0 || to < 0) return;
        order.splice(from, 1);
        order.splice(to, 0, source);
        try { localStorage.setItem('mihomo_overview_order', JSON.stringify(order)); } catch (e) {}
        this.refreshOverview();
    },

    refreshOverview: function() {
        var self = this;
        var safeCall = function(call) { return call().catch(function() { return {}; }); };
        return Promise.all([safeCall(callDnsStatus), safeCall(callRoutingStatus), safeCall(callProfilesList), safeCall(callScheduleList), safeCall(callBackupStatus)]).then(function(data) {
            var dns = data[0] || {}, routing = data[1] || {}, profiles = data[2] || {}, schedules = data[3] || {}, backups = data[4] || {};
            self.backupData = backups;
            self.backupSettings = backups.settings || {};
            var magiStatus = self.magitrickleRunning;
            var magiVersion = self.magitrickleVersion || _('Загрузка...');
             var active = profiles.active || profiles.activeProfile || '—';
             if (active === 'default') active = 'Default';
             var profileCount = (profiles.profiles || []).length;
            var ruleCount = (cachedRuleFiles || []).filter(function(f) { return f.type === 'file'; }).length;
            var clientCount = (routing.rules || []).filter(function(rule) { return rule && (rule.enabled === true || rule.enabled === 1 || rule.enabled === '1'); }).length;
            var scheduleNames = [];
            ((schedules.time || []).concat(schedules.trigger || [])).forEach(function(item) { if (item && item.name && scheduleNames.indexOf(item.name) === -1) scheduleNames.push(item.name); });
            var scheduleActiveCount = scheduleNames.filter(function(name) {
                var timeOn = (schedules.time || []).some(function(item) { return item.name === name && (item.enabled === true || item.enabled === 1 || item.enabled === '1'); });
                var triggerOn = (schedules.trigger || []).some(function(item) { return item.name === name && (item.enabled === true || item.enabled === 1 || item.enabled === '1'); });
                return timeOn || triggerOn;
            }).length;
             var dnsCount = (dns.servers || []).length;
             var backupEnabled = !!(backups.settings && (backups.settings.auto_mihomo || backups.settings.auto_magitrickle));
             var plural = function(n, forms) {
                n = Math.abs(Number(n) || 0);
                var mod10 = n % 10, mod100 = n % 100;
                return (mod10 === 1 && mod100 !== 11) ? n + ' ' + forms[0] : ((mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) ? n + ' ' + forms[1] : n + ' ' + forms[2]);
            };
            var action = function(view) {
                return E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { ev.stopPropagation(); self.switchView(view); } }, _('Открыть'));
            };
            var card = function(id, title, value, detail, cls, button, topButton) {
                var content = [
                    E('div', { class: 'mihomo-overview-card-head' }, [E('div', { class: 'mihomo-overview-card-title' }, title), topButton || '']),
                ];
                if (value !== '') content.push(E('div', { class: 'mihomo-overview-card-value' }, value));
                if (detail) content.push(E('div', { class: 'mihomo-overview-card-detail' }, detail));
                if (button) content.push(E('div', { class: 'mihomo-overview-card-actions' }, button));
                 var cardEl = E('div', { class: 'mihomo-overview-card ' + (cls || ''), draggable: true, 'data-mihomo-card': id }, content);
                cardEl.addEventListener('dragstart', function(ev) {
                    self.overviewDragSource = id;
                    cardEl.classList.add('mihomo-overview-dragging');
                    try { ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', id); } catch (e) {}
                });
                cardEl.addEventListener('dragover', function(ev) { ev.preventDefault(); cardEl.classList.add('mihomo-overview-drag-over'); });
                cardEl.addEventListener('dragleave', function() { cardEl.classList.remove('mihomo-overview-drag-over'); });
                cardEl.addEventListener('drop', function(ev) {
                    ev.preventDefault();
                    cardEl.classList.remove('mihomo-overview-drag-over');
                    var source = self.overviewDragSource || (ev.dataTransfer && ev.dataTransfer.getData('text/plain'));
                    self.overviewDragSource = null;
                    self.moveOverviewCard(source, id);
                });
                cardEl.addEventListener('dragend', function() { self.overviewDragSource = null; cardEl.classList.remove('mihomo-overview-dragging'); });
                return cardEl;
            };
             var serviceButton = self.isRunning
                 ? E('button', { class: 'btn cbi-button-reset mihomo-overview-card-action mihomo-card-stop', click: function(ev) { ev.stopPropagation(); self.handleServiceAction('stop'); } }, _('Остановить'))
                 : E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action mihomo-card-stop', click: function(ev) { ev.stopPropagation(); self.handleServiceAction('start'); } }, _('Запустить'));
               var mihomoDashboard = E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { ev.stopPropagation(); self.handleOpenDashboard(mainConfigContent); } }, _('Панель управления'));
                var mihomoDashboardActions = E('div', { style: 'display:flex; align-items:center; gap:.4rem; margin-left:auto;' }, [mihomoDashboard, self.mihomoDashboardSelect]);
                var mihomoStatusValue = E('div', { style: 'display:flex; align-items:center; width:100%;' }, [
                    E('span', {}, self.isRunning ? _('Работает') : _('Остановлен')),
                    mihomoDashboardActions
                ]);
                var mihomoConfig = E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { ev.stopPropagation(); self.switchView('configs'); } }, _('Конфигурация'));
               var mihomoServiceActions = E('div', { style: 'display:flex; align-items:center; gap:.4rem; margin-left:auto;' }, [self.updateButton, self.mihomoChannelSelect]);
                 var magiServiceButton = self.magitrickleRunning
 ? E('button', { class: 'btn cbi-button-reset mihomo-overview-card-action mihomo-card-stop', click: function(ev) { ev.stopPropagation(); self.handleMagiTrickleAction('stop'); } }, _('Остановить'))
                    : E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action mihomo-card-stop', click: function(ev) { ev.stopPropagation(); self.handleMagiTrickleAction('start'); } }, _('Запустить'));
                 var magiVariantSelect = E('select', { class: 'cbi-input-select', style: 'width:6rem; height:28px;', change: function(ev) { ev.stopPropagation(); self.switchMagiTrickleVariant(ev.target.value, ev.target); } }, [
E('option', { value: 'original' }, 'Original'),
                      E('option', { value: 'mod' }, 'Mod')
                 ]);
                 magiVariantSelect.value = self.magitrickleVariant;
                 self.magitrickleVariantSelect = magiVariantSelect;
                  var magiServiceActions = E('div', { style: 'display:flex; align-items:center; gap:.4rem; margin-left:auto;' }, [self.magitrickleUpdateButton, magiVariantSelect]);
                 var magiAction = E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { ev.stopPropagation(); self.switchView('magitrickle'); } }, _('Конфигурация'));
                 var cards = {
                    mihomo: card('mihomo', _('Mihomo') + ' ' + (self.currentVersion || _('Загрузка...')), mihomoStatusValue, '', self.isRunning ? 'is-ok' : 'is-muted', [mihomoConfig, serviceButton], mihomoServiceActions),
                    magitrickle: card('magitrickle', _('MagiTrickle') + ' ' + magiVersion, magiStatus ? _('Работает') : _('Остановлен'), '', magiStatus ? 'is-ok' : 'is-muted', [magiAction, magiServiceButton], magiServiceActions),
                  profile: card('profile', _('Активная конфигурация Mihomo'), active, '', 'is-muted', action('configs')),
                 schedule: card('schedule', _('Расписание'), plural(scheduleActiveCount, [_('активное расписание'), _('активных расписания'), _('активных расписаний')]), '', 'is-muted', E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { ev.stopPropagation(); self.activeView = 'configs'; self.activeSub = 'schedule'; self.activeThird = 'list'; self.renderSettingsRow(); self.showViewContent(); } }, _('Открыть'))),
                 rules: card('rules', _('Списки правил'), plural(ruleCount, [_('список'), _('списка'), _('списков')]), '', 'is-muted', E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { ev.stopPropagation(); self.activeView = 'configs'; self.activeSub = 'rules'; self.activeThird = 'list'; self.renderSettingsRow(); self.showViewContent(); } }, _('Открыть'))),
                 routing: card('routing', _('Маршрутизация'), plural(clientCount, [_('активный клиент'), _('активных клиента'), _('активных клиентов')]), '', 'is-muted', action('routing')),
                  dns: card('dns', _('DNS'), plural(dnsCount, [_('активный сервер'), _('активных сервера'), _('активных серверов')]), '', 'is-muted', action('dns')),
                  backup: card('backup', _('Резервное копирование'), backupEnabled ? _('Включено') : _('Выключено'), '', backupEnabled ? 'is-ok' : 'is-muted', action('backup'))
             };
            var order = self.getOverviewOrder();
            var ordered = order.map(function(id) { return cards[id]; });
            var rows = [];
            for (var r = 0; r < ordered.length; r += 2) {
                rows.push(E('div', { class: 'mihomo-overview-row' }, E('div', { class: 'mihomo-overview-cards' }, ordered.slice(r, r + 2))));
            }
             L.dom.content(self.overviewPanel, rows);
        }).catch(function(err) { self.showRoutingError({ ok: false, error: _('Не удалось получить состояние') + ': ' + err.message }); });
    },

    refreshMagitrickle: function() {
        var self = this;
        var settle = function(promise, fallback) {
            return new Promise(function(resolve) {
                var done = false;
                var finish = function(v) { if (!done) { done = true; resolve(v); } };
                promise.then(finish).catch(function() { finish(fallback); });
                setTimeout(function() { finish(fallback); }, 15000);
            });
        };
        var apply = function(version, variant) {
            version = String(version || '').replace(/[-_]r\d+$/i, '').replace(/-\d+$/, '');
            var display = version ? (String(version).indexOf('v') === 0 ? String(version) : 'v' + version) : _('Неизвестно');
            self.magitrickleVersion = display;
            self.magitrickleVariant = variant === 'mod' ? 'mod' : 'original';
            if (self.overviewPanel && self.activeView === 'overview') return self.refreshOverview();
            return self.magitrickleVariant;
        };
        var stateP = settle(fs.read('/etc/mixomo/versions/magitrickle'), '');
        var statusP = settle(fs.exec('/bin/sh', ['-c', 'service magitrickle status 2>&1; pidof magitrickled 2>/dev/null; true']), { code: 1 });
        return Promise.all([statusP, stateP]).then(function(data) {
            var status = data[0] || {};
            var state = data[1] || '';
            var stateVariant = (state.match(/^([^\n\r]+)/) || ['', ''])[1].trim();
            var stored = state.replace(/^[^\n]*\n/, '').trim();
            self.magitrickleRunning = isMagiRunningOutput(status);
            var storedMatch = stored.match(/v?[0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*/);
            if (storedMatch) return apply(storedMatch[0], stateVariant);
            return settle(fs.exec('/bin/sh', ['-c', 'if command -v timeout >/dev/null 2>&1; then timeout 5 magitrickled --version 2>&1; else magitrickled --version 2>&1; fi']), { stdout: '' }).then(function(res) {
                var output = ((res && res.stdout) || '').replace(/\x1b\[[0-9;]*m/g, '');
                var match = output.match(/version[= ]+v?([0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*)/i);
                return apply(match ? match[1] : '', stateVariant);
            });
        });
    },

    renderSettingsRow: function() {
        if (!this.settingsRow) return;
        var self = this;
        L.dom.content(this.settingsRow, []);
        var items = [
             { view: 'overview', label: _('Обзор') },
             { view: 'magitrickle', label: _('MagiTrickle') },
             { view: 'configs', label: _('Mihomo') },
            { view: 'routing', label: _('Маршрутизация') },
             { view: 'dns', label: _('DNS') },
              { view: 'backup', label: _('Резервное копирование') }
        ];
        items.forEach(function(it) {
             self.settingsRow.appendChild(makeLuciTab(it.label, self.activeView === it.view, function() { self.switchView(it.view); }));
        });
    },

    switchView: function(view) {
        if (view === 'schedule') {
            this.activeView = 'configs';
            this.activeSub = 'schedule';
            this.activeThird = 'list';
            this.renderSettingsRow();
            this.showViewContent();
            return;
        }
        if (view === this.activeView) {
            this.showViewContent();
            return;
        }
        this.activeView = view;
        this.activeSub = (view === 'routing') ? 'addresses' : ((view === 'schedule') ? 'schedule' : ((view === 'dns') ? 'servers' : 'list'));
        this.activeThird = 'list';
        this.renderSettingsRow();
        this.showViewContent();
    },

    renderSubRow: function() {
        if (!this.subRow) return;
        var self = this;
        L.dom.content(this.subRow, []);
         if (!this.subRowVisible) {
             this.subRow.style.display = 'none';
             if (this.fourthRow) this.fourthRow.style.display = 'none';
             return;
         }
        var items = [];
        if (this.activeView === 'configs') {
            items = [ { s: 'list', label: _('Конфигурации') }, { s: 'rules', label: _('Списки правил') }, { s: 'schedule', label: _('Расписание') } ];
        } else if (this.activeView === 'rules') {
            items = [ { s: 'list', label: _('Все списки правил') }, { s: 'add', label: _('Создать список правил') } ];
        } else if (this.activeView === 'routing') {
            items = [ { s: 'addresses', label: _('Через Mihomo') }, { s: 'exclusions', label: _('Мимо Mihomo') }, { s: 'special', label: _('Дополнительно') } ];
        } else if (this.activeView === 'dns') {
            items = [ { s: 'servers', label: _('DNS-серверы') }, { s: 'add', label: _('Добавить DNS-сервер') } ];
        }
        if (!items.length) {
            this.subRow.style.display = 'none';
            return;
        }
        this.subRow.style.display = 'flex';
        items.forEach(function(it) {
             self.subRow.appendChild(makeLuciTab(it.label, self.activeSub === it.s, function() { self.switchSub(it.s); }));
        });
    },

     renderThirdRow: function() {
         if (!this.thirdRow) return;
         var self = this;
         L.dom.content(this.thirdRow, []);
         if (!this.subRowVisible || this.activeView !== 'configs' || (this.activeSub !== 'rules' && this.activeSub !== 'list' && this.activeSub !== 'schedule')) {
             this.thirdRow.style.display = 'none';
             return;
         }
         this.thirdRow.style.display = 'flex';
         var items = this.activeSub === 'list' ? [ { s: 'list', label: _('Все конфигурации') }, { s: 'add', label: _('Создать конфигурацию') } ] : (this.activeSub === 'rules' ? [ { s: 'list', label: _('Все списки правил') }, { s: 'add', label: _('Создать список правил') } ] : [ { s: 'list', label: _('Все расписание') }, { s: 'add', label: _('Создать расписание') } ]);
        items.forEach(function(it) {
             self.thirdRow.appendChild(makeLuciTab(it.label, self.activeThird === it.s, function() { self.switchThird(it.s); }));
        });
    },

    switchThird: function(third) {
        if (third === this.activeThird) {
            if (this.viewVisible) {
                this.viewVisible = false;
                this.hideAllWindows();
            } else {
                this.showViewContent();
            }
            return;
        }
         this.activeThird = third;
         this.renderThirdRow();
         this.renderFourthRow();
         this.showViewContent();
    },

     renderFourthRow: function() {
         if (!this.fourthRow) return;
         var self = this;
         L.dom.content(this.fourthRow, []);
         if (!this.subRowVisible || this.activeView !== 'configs' || this.activeSub !== 'schedule' || this.activeThird !== 'add') {
             this.fourthRow.style.display = 'none';
             return;
         }
         this.fourthRow.style.display = 'flex';
         [ { s: 'time', label: _('По времени') }, { s: 'trigger', label: _('По триггеру') }, { s: 'combined', label: _('По триггеру и времени') } ].forEach(function(it) {
              self.fourthRow.appendChild(makeLuciTab(it.label, self.activeFourth === it.s, function() { self.switchFourth(it.s); }));
         });
     },

      switchFourth: function(value) {
          this.activeFourth = this.activeFourth === value ? null : value;
          this.renderFourthRow();
          this.renderSchedulePanel();
      },

     switchSub: function(sub) {
         editorRequested = false;
         if (sub === this.activeSub) {
             if (this.viewVisible) {
                 this.viewVisible = false;
                 if (this.thirdRow) this.thirdRow.style.display = 'none';
                 if (this.fourthRow) this.fourthRow.style.display = 'none';
                 this.hideAllWindows();
            } else {
                this.showViewContent();
            }
            return;
        }
         this.activeSub = sub;
          if (sub === 'rules' || sub === 'list' || sub === 'schedule') this.activeThird = 'list';
          this.activeFourth = 'time';
         this.renderSubRow();
         this.renderThirdRow();
         this.renderFourthRow();
         this.showViewContent();
    },

    hideSubRow: function() {
         if (this.subRow) this.subRow.style.display = 'none';
         if (this.thirdRow) this.thirdRow.style.display = 'none';
         if (this.fourthRow) this.fourthRow.style.display = 'none';
         this.hideAllWindows();
    },

    hideAllWindows: function() {
        if (this.overviewPanel) this.overviewPanel.style.display = 'none';
        if (this.routingPanel) this.routingPanel.style.display = 'none';
        if (this.dnsPanel) this.dnsPanel.style.display = 'none';
        if (this.dnsModeRow) this.dnsModeRow.style.display = 'none';
         if (this.schedulePanel) this.schedulePanel.style.display = 'none';
         if (this.magitricklePanel) this.magitricklePanel.style.display = 'none';
         if (this.backupPanel) this.backupPanel.style.display = 'none';
         if (this.filesPanel) this.filesPanel.style.display = 'none';
        if (this.editPanel) this.editPanel.style.display = 'none';
    },

    showViewContent: function() {
         this.subRowVisible = true;
        this.viewVisible = true;
         this.renderSubRow();
         this.renderThirdRow();
         this.renderFourthRow();
         this.hideAllWindows();
         if (this.activeView === 'overview') {
             if (this.overviewPanel) this.overviewPanel.style.display = 'block';
             this.refreshOverview();
         } else if (this.activeView === 'magitrickle') {
             if (this.magitricklePanel) this.magitricklePanel.style.display = 'block';
         } else if (this.activeView === 'backup') {
             if (this.backupPanel) this.backupPanel.style.display = 'block';
             this.refreshBackups();
         } else if (this.activeView === 'rules' && this.activeSub === 'list') {
            this.selectFirstRuleOnOpen = true;
        }
         this.updateVisibility(currentFile);
        if (this.activeView === 'configs') {
            if (this.activeSub === 'schedule') {
                if (this.schedulePanel) this.schedulePanel.style.display = 'block';
                this.refreshSchedule();
            } else if (this.activeSub === 'rules') {
                if (this.filesPanel) this.filesPanel.style.display = 'block';
                if (this.activeThird === 'add') this.refreshProfiles();
                else this.refreshRuleFiles();
            } else {
                if (this.filesPanel) this.filesPanel.style.display = 'block';
                this.refreshProfiles();
            }
        } else if (this.activeView === 'rules') {
            if (this.filesPanel) this.filesPanel.style.display = 'block';
            if (this.activeSub === 'list') this.refreshRuleFiles();
            else this.refreshProfiles();
        } else if (this.activeView === 'routing') {
            if (this.routingPanel) this.routingPanel.style.display = 'block';
            this.refreshRouting();
         } else if (this.activeView === 'dns') {
             this.dnsModeVisible = true;
             this.renderDnsModeRow();
             if (this.dnsModeRow) this.dnsModeRow.style.display = this.activeSub === 'add' ? 'flex' : 'none';
             if (this.dnsPanel) this.dnsPanel.style.display = 'block';
             this.refreshDns();
        } else if (this.activeView === 'schedule') {
            if (this.schedulePanel) this.schedulePanel.style.display = 'block';
            this.refreshSchedule();
        }
    },

    mkSegRow: function(items, current, onclick) {
        var row = E('div', { 'class': 'mihomo-seg' });
        items.forEach(function(it) {
            row.appendChild(E('button', { 'class': 'btn cbi-button-neutral' + (it.value === current ? ' active' : ''), 'click': function() { onclick(it.value); } }, it.label));
        });
        return row;
    },

    backupComponentLabel: function(component) {
        return { all: _('Все компоненты'), mihomo: _('Mihomo'), dns: _('DNS'), schedule: _('Mihomo'), magitrickle: _('MagiTrickle'), routing: _('Маршрутизация') }[component] || component;
    },

    refreshBackups: function() {
        var self = this;
        return callBackupStatus().then(function(data) {
            self.backupData = data || {};
            self.backupSettings = self.backupData.settings || {};
            var panel = self.backupPanel;
            if (!panel) return;
              var componentNames = [
                  { value: 'magitrickle', label: _('MagiTrickle') },
                  { value: 'mihomo', label: _('Mihomo') },
                  { value: 'routing', label: _('Маршрутизация') },
                  { value: 'dns', label: _('DNS') }
              ];
              var allCheck = E('input', { type: 'checkbox' });
              var componentChecks = [];

              
               var retention = E('input', { type: 'number', min: 1, max: 20, value: self.backupSettings.retention || 1, style: 'width:5rem;' });
               var retentionRow = E('label', { style: 'display:block; margin:.4rem 0;' }, [_('Максимальное количество копий для каждого компонента: '), retention]);
              var componentRows = [E('label', { style: 'display:block; margin:.35rem 0;' }, [allCheck, ' ', _('Все компоненты')])];
             componentNames.forEach(function(item) {
                 var check = E('input', { type: 'checkbox' });
                 componentChecks.push({ value: item.value, check: check });
                 componentRows.push(E('label', { style: 'display:block; margin:.35rem 0;' }, [check, ' ', item.label]));
                 check.addEventListener('change', function() { allCheck.checked = false; });
             });
             allCheck.addEventListener('change', function() {
                 componentChecks.forEach(function(item) { item.check.checked = allCheck.checked; });
             });
             var create = E('button', { class: 'btn cbi-button-positive', click: function() {
                 var selected = componentChecks.filter(function(item) { return item.check.checked; }).map(function(item) { return item.value; });
                 if (allCheck.checked) selected = ['all'];
                 if (!selected.length) {
                     ui.addNotification(null, E('p', _('Выберите хотя бы один компонент')), 'error');
                     return;
                 }
                 self.createBackups(selected);
             } }, _('Создать копию'));
             create.style.display = 'block';
              create.style.margin = '0';
             var autoMihomo = E('input', { type: 'checkbox' });
            autoMihomo.checked = !!self.backupSettings.auto_mihomo;
            var autoMagi = E('input', { type: 'checkbox' });
            autoMagi.checked = !!self.backupSettings.auto_magitrickle;
            
              var saveAutoSettings = function() {
                  callBackupSettings(retention.value || 1, autoMihomo.checked, autoMagi.checked).then(function(res) {
                      if (!res || !res.ok) throw new Error((res && res.error) || _('Не удалось сохранить настройки'));
                      self.backupSettings = res.settings || self.backupSettings;
                  }).catch(function(err) { ui.addNotification(null, E('p', err.message), 'error'); });
              };
              autoMihomo.addEventListener('change', saveAutoSettings);
              autoMagi.addEventListener('change', saveAutoSettings);
              retention.addEventListener('change', saveAutoSettings);
             var rows = [
                 E('h3', {}, _('Автоматическое копирование перед обновлением')),
                 E('div', { style: 'margin-bottom:0;' }, [
                     E('label', { style: 'display:block; margin:.35rem 0;' }, [autoMihomo, ' ', _('Mihomo')]),
                     E('label', { style: 'display:block; margin:.35rem 0 0;' }, [autoMagi, ' ', _('MagiTrickle')])
                 ]),
                  E('h3', {}, _('Ручное копирование')),
                  E('div', { style: 'margin-bottom:0;' }, componentRows.concat([retentionRow, create])),
                E('h3', { style: 'margin:.8rem 0 .5rem;' }, _('Сохранённые копии'))
            ];
            var backups = self.backupData.backups || [];
            if (!backups.length) rows.push(E('p', {}, _('Резервных копий пока нет.')));
             var backupOrder = { all: 0, magitrickle: 1, mihomo: 2, schedule: 2, routing: 3, dns: 4 };
             backups.sort(function(a, b) {
                 var ao = backupOrder[a.component] == null ? 99 : backupOrder[a.component];
                 var bo = backupOrder[b.component] == null ? 99 : backupOrder[b.component];
                 return ao === bo ? Number(b.created) - Number(a.created) : ao - bo;
             });
            backups.forEach(function(item) {
                var restore = E('button', { class: 'btn cbi-button-neutral', click: function() { self.restoreBackup(item.file); } }, _('Восстановить'));
                var remove = E('button', { class: 'btn cbi-button-reset', click: function() { self.deleteBackup(item.file); } }, _('Удалить'));
                var date = new Date(Number(item.created) * 1000).toLocaleString();
                rows.push(E('div', { style: 'display:flex; align-items:center; gap:.5rem; flex-wrap:wrap; border-bottom:1px solid var(--border-color); padding:.6rem 0;' }, [
                    E('strong', {}, self.backupComponentLabel(item.component)),
                    E('span', { style: 'opacity:.75;' }, date),
                    E('span', { style: 'opacity:.75; flex:1;' }, item.file),
                    restore, remove
                ]));
            });
            L.dom.content(panel, rows);
        }).catch(function(err) { ui.addNotification(null, E('p', err.message || _('Не удалось получить резервные копии')), 'error'); });
    },

    createBackups: function(components) {
        var self = this;
        var run = function(index) {
            if (index >= components.length) return Promise.resolve();
            return callBackupCreate(components[index]).then(function(res) {
                if (!res || !res.ok) throw new Error((res && res.error) || _('Не удалось создать копию'));
                return run(index + 1);
            });
        };
        run(0).then(function() {
            self.refreshBackups();
            if (self.activeView === 'overview') self.refreshOverview();
        }).catch(function(err) { ui.addNotification(null, E('p', err.message), 'error'); });
    },

    createBackup: function(component) {
        this.createBackups([component]);
    },

    deleteBackup: function(file) {
        var self = this;
        callBackupDelete(file).then(function(res) {
            if (!res || !res.ok) throw new Error((res && res.error) || _('Не удалось удалить копию'));
            self.refreshBackups();
        }).catch(function(err) { ui.addNotification(null, E('p', err.message), 'error'); });
    },

    restoreBackup: function(file) {
        var self = this;
        ui.showModal(_('Подтверждение'), [
            E('p', {}, _('Восстановить выбранную резервную копию?')),
            E('div', { class: 'right' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отмена')), ' ',
                E('button', { class: 'btn cbi-button-positive', click: function() {
                    callBackupRestore(file).then(function(res) {
                        if (!res || !res.ok) throw new Error((res && res.error) || _('Не удалось восстановить копию'));
                        ui.hideModal();
                        ui.addNotification(null, E('p', _('Копия восстановлена. Перезапустите службы при необходимости.')), 'info');
                    }).catch(function(err) { ui.hideModal(); ui.addNotification(null, E('p', err.message), 'error'); });
                } }, _('Восстановить'))
            ])
        ]);
    },

     refreshDns: function() {
         var self = this;
         var refreshToken = ++this.dnsRefreshToken;
         var orderGeneration = this.dnsOrderGeneration || 0;
         return callDnsStatus().then(function(res) {
             if (refreshToken !== self.dnsRefreshToken) return;
             if (!res || res.ok !== true) { self.showRoutingError(res || { ok: false, error: _('Не удалось получить состояние DNS') }); return; }
             self.dnsData = res;
             var servers = res.servers || [];
             var custom = res.custom || [];
             var checks = {};
             custom.forEach(function(c) { checks[c.name] = c.value.split(/\s+/).every(function(v) { return servers.indexOf(v) !== -1; }); });
             self.dnsChecks = checks;
              var customNames = custom.map(function(c) { return c.name; });
              var order = (res.order || []).filter(function(name) { return customNames.indexOf(name) !== -1; });
              custom.forEach(function(c) { if (order.indexOf(c.name) === -1) order.push(c.name); });
              if (orderGeneration === (self.dnsOrderGeneration || 0)) self.dnsOrder = order;

             self.dnsUsageMode = res.allServers ? 'parallel' : (res.strictOrder ? 'strict' : 'standard');
             self.dnsManualText = res.config || '';
             self.renderDnsModeRow();
             self.renderDnsPanel();
         }).catch(function(err) { if (refreshToken === self.dnsRefreshToken) ui.addNotification(null, E('p', _('Ошибка DNS: ') + err.message), 'error'); });
     },


    renderDnsPanel: function() {
        var panel = this.dnsPanel;
        if (!panel) return;
        while (panel.firstChild) panel.removeChild(panel.firstChild);
        if (this.activeSub === 'add') {
            if (this.dnsMode === 'manual') {
                this.renderDnsManual(panel);
            } else {
                this.renderDnsAddSimple(panel);
            }
        } else {
            this.renderDnsServers(panel);
        }
    },

    renderDnsModeRow: function() {
        if (!this.dnsModeRow) return;
        var self = this;
        L.dom.content(this.dnsModeRow, []);
         this.dnsModeRow.appendChild(makeLuciTab(_('Простое добавление'), this.dnsMode === 'simple', function() { self.switchDnsMode('simple'); }));
         this.dnsModeRow.appendChild(makeLuciTab(_('Ручное добавление'), this.dnsMode === 'manual', function() { self.switchDnsMode('manual'); }));
    },

     switchDnsMode: function(v) {
         if (v === this.dnsMode) {
             this.dnsModeVisible = !this.dnsModeVisible;
             if (this.dnsPanel) this.dnsPanel.style.display = this.dnsModeVisible ? 'block' : 'none';
             return;
         }
         this.dnsModeVisible = true;
         if (v === 'manual') {
            this.dnsManualText = (this.dnsData && this.dnsData.config) || '';
        }
        this.dnsMode = v;
        this.renderDnsModeRow();
        this.renderDnsPanel();
    },

    renderDnsServers: function(panel) {
        var self = this;
        var checks = this.dnsChecks || {};
        var order = this.dnsOrder || [];
        var custom = (this.dnsData && this.dnsData.custom) || [];
        var dnsModes = [
            { value: 'strict', label: _('По порядку'), desc: _('Обязательный режим для использования секции DNS в Mihomo') },
            { value: 'standard', label: _('Стандартный'), desc: _('Автоматический выбор самого быстрого сервера.') },
            { value: 'parallel', label: _('Параллельный'), desc: _('Запрос ко всем серверам сразу, ответ от самого первого.') }
        ];
        panel.appendChild(E('h4', _('Режим использования DNS')));
        dnsModes.forEach(function(mo) {
            panel.appendChild(E('p', { style: 'opacity:.8; margin:.4rem 0 0;' }, mo.desc));
            var cb = E('input', { type: 'checkbox', style: 'flex-shrink:0; margin:0;', click: function() { self.dnsUsageMode = mo.value; self.renderDnsPanel(); } });
            cb.checked = (self.dnsUsageMode === mo.value);
            panel.appendChild(E('label', { style: 'display:flex; align-items:center; gap:.6rem; margin:.1rem 0 .6rem;' }, [cb, E('span', {}, mo.label)]));
        });
        panel.appendChild(E('h4', { style: 'margin-bottom:.5rem;' }, _('DNS-серверы')));
        var ordinals = [_('Первый'), _('Второй'), _('Третий'), _('Четвёртый'), _('Пятый'), _('Шестой'), _('Седьмой'), _('Восьмой'), _('Девятый'), _('Десятый')];
        var pos = 0;
        var grid = E('div', { class: 'mihomo-overview-cards' });
        order.forEach(function(name) {
            var values = [];
            custom.forEach(function(c) { if (c.name === name) values = values.concat(c.value.split(/\s+/)); });
            if (!values.length) return;
            pos++;
            var num = pos <= ordinals.length ? ordinals[pos - 1] : (pos + '-й');
            var on = !!checks[name];
            var valueText = values.join(' ');
            var cardEl = E('div', { class: 'mihomo-overview-card ' + (on ? 'is-ok' : 'is-muted'), draggable: true }, [
                E('div', { class: 'mihomo-overview-card-head' }, [E('div', { class: 'mihomo-overview-card-title' }, name), E('span', { style: 'color:var(--text-dim); font-size:.98em;' }, num)]),
                E('div', { class: 'mihomo-overview-card-detail' }, valueText),
                E('div', { class: 'mihomo-overview-card-actions' }, [
                    E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { var card = ev.currentTarget; while (card && !card.classList.contains('mihomo-overview-card')) card = card.parentNode; if (card) self.openDnsCardEdit(card, name, valueText); } }, _('Изменить данные')),
                    E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { self.dnsChecks[name] = !on; self.renderDnsPanel(); } }, on ? _('Отключить') : _('Включить')),
                    E('button', { class: 'btn cbi-button-reset mihomo-overview-card-action', click: function() {
                        callDnsRemovePreset(name).then(function(res) { if (self.showRoutingError(res)) self.refreshDns(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                    } }, _('Удалить'))
                ])
            ]);
            cardEl.addEventListener('dragstart', function(ev) {
                self.dnsDragName = name;
                cardEl.classList.add('mihomo-overview-dragging');
                try { ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', name); } catch (e) {}
            });
            cardEl.addEventListener('dragover', function(ev) { ev.preventDefault(); cardEl.classList.add('mihomo-overview-drag-over'); });
            cardEl.addEventListener('dragleave', function() { cardEl.classList.remove('mihomo-overview-drag-over'); });
            cardEl.addEventListener('drop', function(ev) {
                ev.preventDefault();
                cardEl.classList.remove('mihomo-overview-drag-over');
                var source = self.dnsDragName || (ev.dataTransfer && ev.dataTransfer.getData('text/plain'));
                self.dnsDragName = null;
                if (source) self.moveDnsCard(source, name);
            });
            cardEl.addEventListener('dragend', function() { self.dnsDragName = null; cardEl.classList.remove('mihomo-overview-dragging'); });
            grid.appendChild(cardEl);
        });
        panel.appendChild(grid);
        var cleanCb = E('input', { type: 'checkbox', style: 'flex-shrink:0; margin:0;', click: function() { self.dnsClean = cleanCb.checked; } });
        cleanCb.checked = !!this.dnsClean;
        panel.appendChild(E('label', { style: 'display:flex; align-items:center; gap:.6rem; margin:.8rem 0 .4rem;' }, [cleanCb, E('span', {}, _('Очистить /etc/dnsmasq.conf перед применением'))]));
        panel.appendChild(E('div', { style: 'margin-top:.8rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive', click: function() { self.applySimpleDns(); } }, _('Применить'))
        ]));
    },

    renderDnsAddSimple: function(panel) {
        var self = this;
        var order = this.dnsOrder || [];
        var nameIn = E('input', { type: 'text', placeholder: '', value: this.dnsCustomName || '', style: 'min-width:12rem;', input: function() { self.dnsCustomName = nameIn.value; } });
        var valIn = E('input', { type: 'text', placeholder: '', value: this.dnsCustomValue || '', style: 'min-width:12rem;', input: function() { self.dnsCustomValue = valIn.value; } });
        panel.appendChild(E('div', { class: 'mihomo-route-add', style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem; margin:.4rem 0;' }, [
            E('span', {}, _('Название (необязательно)')), nameIn,
            E('span', {}, _('IP (можно указать несколько через пробел)')), valIn,
            E('button', { 'class': 'btn cbi-button-positive', click: function() {
                var nm = nameIn.value.trim();
                 if (!nm) {
                     nm = valIn.value.trim();
                     var suffix = 2;
                     var baseName = nm;
                     while (order.indexOf(nm) !== -1) { nm = baseName + ' (' + suffix + ')'; suffix++; }
                 }
                if (!isValidDnsValue(valIn.value.trim())) { ui.addNotification(null, E('p', _('Некорректный DNS: укажите IPv4 с октетами не длиннее 3 цифр (например 8.8.8.8 или 127.0.0.1#7880)')), 'error'); return; }
                 callDnsAddPreset(nm, valIn.value.trim()).then(function(res) {
                     if (self.showRoutingError(res)) {
                         self.dnsCustomName = ''; self.dnsCustomValue = '';
                         ui.addNotification(null, E('p', _('DNS-сервер создан')), 'info');
                     }
                     self.refreshDns();
                }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            }}, _('Добавить DNS'))
        ]));
    },

    moveDnsCard: function(sourceName, targetName) {
        if (!sourceName || !targetName || sourceName === targetName) return;
        var order = (this.dnsOrder || []).slice();
        var from = order.indexOf(sourceName), to = order.indexOf(targetName);
        if (from === -1 || to === -1) return;
        order.splice(to, 0, order.splice(from, 1)[0]);
         this.dnsOrder = order;
         this.dnsOrderGeneration = (this.dnsOrderGeneration || 0) + 1;
         this.renderDnsPanel();
         this.saveDnsOrder(this.dnsOrderGeneration);
    },

    openDnsCardEdit: function(cardEl, name, value) {
        var self = this;
        var actions = cardEl.querySelector('.mihomo-overview-card-actions');
        if (!actions || cardEl.querySelector('.mihomo-config-card-edit')) return;
        actions.style.display = 'none';
        var head = cardEl.querySelector('.mihomo-overview-card-head');
        var details = cardEl.querySelectorAll('.mihomo-overview-card-detail');
        if (head) head.style.display = 'none';
        for (var di = 0; di < details.length; di++) details[di].style.display = 'none';
        var field = function(label, input) { return E('div', { style: 'margin:.35rem 0;' }, [E('label', { style: 'display:block; opacity:.8; margin-bottom:.15rem;' }, label), input]); };
        var nameInput = E('input', { type: 'text', value: name, style: 'width:100%; box-sizing:border-box;' });
        var valueInput = E('input', { type: 'text', value: value || '', style: 'width:100%; box-sizing:border-box;' });
        var edit = E('div', { class: 'mihomo-config-card-edit', style: 'margin-top:.8rem;' }, [
            field(_('Название (необязательно)'), nameInput),
            field(_('IP (можно указать несколько через пробел)'), valueInput),
            E('div', { style: 'display:flex; gap:.5rem; margin-top:.6rem;' }, [
                E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action', click: function() {
                    var nm = nameInput.value.trim();
                    if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                    var val = valueInput.value.trim();
                    if (!isValidDnsValue(val)) { ui.addNotification(null, E('p', _('Некорректный DNS: укажите IPv4 с октетами не длиннее 3 цифр (например 8.8.8.8 или 127.0.0.1#7880)')), 'error'); return; }
                    if (nm === name && val === value) {
                        edit.remove(); actions.style.display = 'flex'; if (head) head.style.display = ''; for (var i = 0; i < details.length; i++) details[i].style.display = '';
                        return;
                    }
                     callDnsRenamePreset(name, nm, val).then(function(res) {
                         if (self.showRoutingError(res)) self.refreshDns();
                     }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                } }, _('Сохранить')),
                E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { edit.remove(); actions.style.display = 'flex'; if (head) head.style.display = ''; for (var i = 0; i < details.length; i++) details[i].style.display = ''; } }, _('Закрыть'))
            ])
        ]);
        cardEl.insertBefore(edit, actions);
    },

    buildDnsBlock: function() {
        var checks = this.dnsChecks || {};
        var custom = (this.dnsData && this.dnsData.custom) || [];
        var order = this.dnsOrder || [];
        var selected = 0;
        var lines = ['no-resolv'];
        if (this.dnsUsageMode === 'parallel') lines.push('all-servers');
        else if (this.dnsUsageMode === 'strict') lines.push('strict-order');
        order.forEach(function(name) {
            if (!checks[name]) return;
            selected++;
            var values = [];
            custom.forEach(function(c) { if (c.name === name) values = values.concat(c.value.split(/\s+/)); });
            values.forEach(function(v) { lines.push('server=' + v); });
        });
        return { lines: lines, selected: selected };
    },

    saveDnsOrder: function(generation) {
        var self = this;
        var block = this.buildDnsBlock();
        var names = (this.dnsOrder || []).join(',');
        generation = generation == null ? (this.dnsOrderGeneration || 0) : generation;
        this.dnsOrderSave = (this.dnsOrderSave || Promise.resolve()).then(function() {
            return callDnsSetOrder(names).then(function(res) {
                if (!self.showRoutingError(res)) throw new Error(_('Не удалось сохранить порядок DNS'));
                return block.selected ? callDnsApply(block.lines.join('\n'), false) : callDnsClear();
            }).then(function(res) {
                if (!self.showRoutingError(res)) return;
                if (generation !== self.dnsOrderGeneration) return;
                return self.refreshDns();
            });
        }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
    },

    applySimpleDns: function() {
        var self = this;
        var block = this.buildDnsBlock();
        var selected = block.selected;
        var lines = block.lines;
        if (selected === 0) {
            if (!confirm(_('Ничего не выбрано. Удалить все правила DNS из dnsmasq?'))) return;
            var clearPromise = this.dnsClean ? callDnsApply('', true) : callDnsClear();
            return clearPromise.then(function(res) { if (self.showRoutingError(res)) self.refreshDns(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
        }
        var doApply = function(clean) {
            ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Применение...'))]);
            callDnsApply(lines.join('\n'), !!clean).then(function(res) {
                ui.hideModal();
                if (self.showRoutingError(res)) self.refreshDns();
            }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
        };
        if (this.dnsClean) {
            ui.showModal(_('Подтверждение'), [
                E('p', {}, _('Файл /etc/dnsmasq.conf будет полностью очищен, останутся только ваши правила.')),
                E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                    E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Выйти')), ' ',
                    E('button', { class: 'btn cbi-button-positive', click: function() { ui.hideModal(); doApply(true); } }, _('Очистить и применить'))
                ])
            ]);
        } else {
            doApply(false);
        }
    },

    renderDnsManual: function(panel) {
        var self = this;
        var ta = E('textarea', { 'class': 'mihomo-dns-text', style: 'width:100%; height:41em; margin-top:.7rem;' });
         panel.appendChild(E('h4', {}, _('Редактирование файла /etc/dnsmasq.conf')));
        ta.value = this.dnsManualText || '';
        panel.appendChild(ta);
        panel.appendChild(E('div', { style: 'margin-top:.8rem; display:flex; gap:.5rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive', click: function() {
                ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Применение...'))]);
                callDnsApplyFull(ta.value).then(function(res) {
                    ui.hideModal();
                    if (self.showRoutingError(res)) { self.dnsManualText = ta.value; self.refreshDns(); }
                }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            }}, _('Применить')),
            E('button', { 'class': 'btn cbi-button-reset', click: function() {
                if (!confirm(_('Удалить правила DNS Mixomo из dnsmasq?'))) return;
                callDnsClear().then(function(res) { if (self.showRoutingError(res)) self.refreshDns(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            }}, _('Удалить'))
        ]));
    },

    renderRoutingPanel: function() {
        var panel = this.routingPanel;
        if (!panel) return;
        if (this.activeSub === 'exclusions') {
            this.renderRoutingExcl(panel);
        } else if (this.activeSub === 'special') {
            this.renderRoutingSpecial(panel);
        } else {
            this.renderRoutingAddr(panel);
        }
    },

    renderRoutingAddr: function(panel) {
        var self = this, status = this.routingData || {}, clients = (this.clientData && this.clientData.clients) || [];
        while (panel.firstChild) panel.removeChild(panel.firstChild);
        var redirAvail = !!(status.redirAvailable === true || status.redirAvailable === 1 || status.redirAvailable === '1');
        var defaultBackend = (status.variant === 'redir-tproxy') ? 'redir-tproxy' : 'tun-socks5';
         var backendSel = makeRoutingBackend(defaultBackend, redirAvail);
        panel.appendChild(E('p', { style: 'opacity:.75; margin-top:0;' }, [
        _('При добавлении абсолютно весь трафик устройств направляется через Mihomo'),
        E('br'),
        _('Прикрепить IP к устройству можно в '),
        E('a', { href: L.url('admin/network/dhcp'), target: '_blank' }, _('Статических арендах DHCP'))]));

        var routeLabel = E('input', { type: 'text', placeholder: '', style: 'min-width:12rem;' });
        var known = E('select', { style: 'min-width:15rem;' }, [E('option', { value: '' }, _('Выберите устройство...'))].concat(clients.map(function(c) {
            return E('option', { value: c.ip }, (c.name ? c.name + ' — ' : '') + c.ip);
        })));
        var source = E('input', { type: 'text', placeholder: '', style: 'min-width:15rem;' });
        var routeMode = 'auto';
        var autoBox = E('div', { style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem;' }, [
            known
        ]);
        var manualBox = E('div', { style: 'display:none; flex-direction:column; align-items:flex-start; gap:.4rem;' }, [
            source
        ]);
        var modeRow = E('div', { class: 'mihomo-seg', style: 'margin:0;' });
        var autoBtn = E('button', { class: 'btn cbi-button-positive mihomo-route-choice active', click: function() {
            routeMode = 'auto';
            autoBtn.classList.add('active', 'cbi-button-positive');
            autoBtn.classList.remove('cbi-button-neutral');
            manualBtn.classList.remove('active', 'cbi-button-positive');
            manualBtn.classList.add('cbi-button-neutral');
            autoBox.style.display = 'flex';
            manualBox.style.display = 'none';
        } }, _('Системный'));
        var manualBtn = E('button', { class: 'btn cbi-button-neutral mihomo-route-choice', click: function() {
            routeMode = 'manual';
            manualBtn.classList.add('active', 'cbi-button-positive');
            manualBtn.classList.remove('cbi-button-neutral');
            autoBtn.classList.remove('active', 'cbi-button-positive');
            autoBtn.classList.add('cbi-button-neutral');
            manualBox.style.display = 'flex';
            autoBox.style.display = 'none';
        } }, _('Ручной'));
         modeRow.appendChild(autoBtn);
         modeRow.appendChild(manualBtn);
         panel.appendChild(E('div', { class: 'mihomo-route-add', style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem; margin:.4rem 0;' }, [
             E('span', {}, _('Название (необязательно)')), routeLabel,
             E('span', {}, _('Тип подключения')), backendSel,
             E('span', {}, _('IP или CIDR')), modeRow, autoBox, manualBox,
             E('button', { class: 'btn cbi-button-positive', style: 'margin-top:.8rem;', click: function() {
                 var name = routeLabel.value.trim();
                if (routeMode === 'manual') {
                    var manual = source.value.trim();
                    if (!manual) { ui.addNotification(null, E('p', _('Укажите IP или CIDR')), 'error'); return; }
                    callRoutingAdd(manual, name, backendSel.value).then(function(res) { if (self.showRoutingError(res)) { source.value = ''; routeLabel.value = ''; known.value = ''; self.refreshRouting(); } });
                    return;
                }
                if (!known.value) { ui.addNotification(null, E('p', _('Сначала выберите устройство')), 'error'); return; }
                var selected = clients.filter(function(c) { return c.ip === known.value; })[0];
                var label = name || (selected && selected.name) || '';
                callRoutingAdd(known.value, label, backendSel.value).then(function(res) { if (self.showRoutingError(res)) { known.value = ''; routeLabel.value = ''; source.value = ''; self.refreshRouting(); } });
            }}, _('Добавить'))]));

         panel.appendChild(E('h4', { style: 'margin-top:1rem;' }, _('Адреса')));
         var rules = (status.rules || []).slice().sort(function(a, b) { return (a.priority || 0) - (b.priority || 0); });
        if (!rules.length) panel.appendChild(E('p', { style: 'opacity:.75; margin-top:.35rem; margin-bottom:1.35rem;' }, [
            _('Адресов пока нет.')
        ]));
        else {
            var grid = E('div', { class: 'mihomo-overview-cards' });
             rules.forEach(function(rule) {
                 var enabled = isEnabledValue(rule.enabled);
                 var addr = displaySource(rule.source);
                var rows = [E('div', { class: 'mihomo-overview-card-head' }, E('div', { class: 'mihomo-overview-card-title' }, rule.label || addr || '—'))];
                if (rule.label) rows.push(E('div', { class: 'mihomo-overview-card-detail' }, addr));
                rows.push(E('div', { class: 'mihomo-overview-card-detail' }, backendLabel(rule.backend || 'tun-socks5')));
                rows.push(E('div', { class: 'mihomo-overview-card-actions' }, [
                    E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { var card = ev.currentTarget; while (card && !card.classList.contains('mihomo-overview-card')) card = card.parentNode; if (card) self.openRoutingCardEdit(card, rule); } }, _('Изменить данные')),
                    E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { callRoutingEnabled(rule.id, !enabled).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }); } }, enabled ? _('Отключить') : _('Включить')),
                    E('button', { class: 'btn cbi-button-reset mihomo-overview-card-action', click: function() { if (confirm(_('Удалить это правило?'))) callRoutingDelete(rule.id).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }); } }, _('Удалить'))
                ]));
                var cardEl = E('div', { class: 'mihomo-overview-card ' + (enabled ? 'is-ok' : 'is-muted'), draggable: true }, rows);
                cardEl.addEventListener('dragstart', function(ev) {
                    self.routingDragId = String(rule.id);
                    cardEl.classList.add('mihomo-overview-dragging');
                    try { ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', String(rule.id)); } catch (e) {}
                });
                cardEl.addEventListener('dragover', function(ev) { ev.preventDefault(); cardEl.classList.add('mihomo-overview-drag-over'); });
                cardEl.addEventListener('dragleave', function() { cardEl.classList.remove('mihomo-overview-drag-over'); });
                cardEl.addEventListener('drop', function(ev) {
                    ev.preventDefault();
                    cardEl.classList.remove('mihomo-overview-drag-over');
                    var source = self.routingDragId || (ev.dataTransfer && ev.dataTransfer.getData('text/plain'));
                    self.routingDragId = null;
                    if (source != null) self.moveRoutingCard('rule', String(source), String(rule.id));
                });
                cardEl.addEventListener('dragend', function() { self.routingDragId = null; cardEl.classList.remove('mihomo-overview-dragging'); });
                grid.appendChild(cardEl);
            });
            panel.appendChild(grid);
        }
    },

    moveRoutingCard: function(type, sourceId, targetId) {
        if (!sourceId || !targetId || sourceId === targetId) return;
        var status = this.routingData || {};
        var arr = ((type === 'exclude' ? status.exclusions : status.rules) || []).slice().sort(function(a, b) { return (a.priority || 0) - (b.priority || 0); });
        var from = -1, to = -1;
        arr.forEach(function(r, idx) {
            if (String(r.id) === String(sourceId)) from = idx;
            if (String(r.id) === String(targetId)) to = idx;
        });
        if (from === -1 || to === -1) return;
        arr.splice(to, 0, arr.splice(from, 1)[0]);
        this.handleReorder(type, arr.map(function(r) { return r.id; }));
    },

    renderRoutingExcl: function(panel) {
        var self = this, status = this.routingData || {};
        while (panel.firstChild) panel.removeChild(panel.firstChild);
        panel.appendChild(E('p', { style: 'opacity:.75; margin-top:0;' }, [
            _('Трафик к этим адресам никогда не направляется через Mihomo.'),
            E('br'),
            _('По умолчанию добавлены следующие подсети, без возможности их удалить:'),
            E('br'),
            _('127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16, 224.0.0.0/4, 255.255.255.255/32')
        ]));
        var exDest = E('input', { type: 'text', placeholder: '', style: 'min-width:12rem;' });
var exLabel = E('input', { type: 'text', placeholder: '', style: 'min-width:12rem;' });
          panel.appendChild(E('div', { class: 'mihomo-route-add', style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem; margin:.4rem 0;' }, [
              E('span', {}, _('Название (необязательно)')), exLabel,
             E('span', {}, _('IP или CIDR')), exDest,
             E('button', { class: 'btn cbi-button-positive', style: 'margin-top:.8rem;', click: function() {
                callRoutingExcludeAdd(exDest.value.trim(), exLabel.value.trim()).then(function(res) { if (self.showRoutingError(res)) { exDest.value = ''; exLabel.value = ''; self.refreshRouting(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            }}, _('Добавить'))]));
         panel.appendChild(E('h4', { style: 'margin-top:1rem;' }, _('Адреса')));
         var exclusions = (status.exclusions || []).slice().sort(function(a, b) { return (a.priority || 0) - (b.priority || 0); });
        if (!exclusions.length) {
            panel.appendChild(E('p', { style: 'opacity:.75; margin-top:.35rem;' }, _('Адресов пока нет.')));
        } else {
            var grid2 = E('div', { class: 'mihomo-overview-cards' });
             exclusions.forEach(function(ex) {
                 var enabled = isEnabledValue(ex.enabled);
                 var dest = displaySource(ex.dest);
                var rows = [E('div', { class: 'mihomo-overview-card-head' }, E('div', { class: 'mihomo-overview-card-title' }, ex.label || dest || '—'))];
                if (ex.label) rows.push(E('div', { class: 'mihomo-overview-card-detail' }, dest));
                rows.push(E('div', { class: 'mihomo-overview-card-actions' }, [
                    E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { var card = ev.currentTarget; while (card && !card.classList.contains('mihomo-overview-card')) card = card.parentNode; if (card) self.openExclusionCardEdit(card, ex); } }, _('Изменить данные')),
                    E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { callRoutingExcludeEnabled(ex.id, !enabled).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } }, enabled ? _('Отключить') : _('Включить')),
                    E('button', { class: 'btn cbi-button-reset mihomo-overview-card-action', click: function() { if (confirm(_('Удалить этот адрес?'))) callRoutingExcludeDelete(ex.id).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } }, _('Удалить'))
                ]));
                var cardEl = E('div', { class: 'mihomo-overview-card ' + (enabled ? 'is-ok' : 'is-muted'), draggable: true }, rows);
                cardEl.addEventListener('dragstart', function(ev) {
                    self.routingDragId = String(ex.id);
                    cardEl.classList.add('mihomo-overview-dragging');
                    try { ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', String(ex.id)); } catch (e) {}
                });
                cardEl.addEventListener('dragover', function(ev) { ev.preventDefault(); cardEl.classList.add('mihomo-overview-drag-over'); });
                cardEl.addEventListener('dragleave', function() { cardEl.classList.remove('mihomo-overview-drag-over'); });
                cardEl.addEventListener('drop', function(ev) {
                    ev.preventDefault();
                    cardEl.classList.remove('mihomo-overview-drag-over');
                    var source = self.routingDragId || (ev.dataTransfer && ev.dataTransfer.getData('text/plain'));
                    self.routingDragId = null;
                    if (source != null) self.moveRoutingCard('exclude', String(source), String(ex.id));
                });
                cardEl.addEventListener('dragend', function() { self.routingDragId = null; cardEl.classList.remove('mihomo-overview-dragging'); });
                grid2.appendChild(cardEl);
            });
            panel.appendChild(grid2);
        }
    },

    getSpecialOrder: function() {
        var def = ['udp443', 'router'];
        try {
            var saved = JSON.parse(localStorage.getItem('mihomo_special_order') || 'null');
            if (Array.isArray(saved) && saved.length === def.length && def.every(function(id) { return saved.indexOf(id) >= 0; })) return saved;
        } catch (e) {}
        return def;
    },

    moveSpecialCard: function(sourceId, targetId) {
        if (!sourceId || !targetId || sourceId === targetId) return;
        var order = this.getSpecialOrder();
        var from = order.indexOf(sourceId), to = order.indexOf(targetId);
        if (from === -1 || to === -1) return;
        order.splice(to, 0, order.splice(from, 1)[0]);
        try { localStorage.setItem('mihomo_special_order', JSON.stringify(order)); } catch (e) {}
        this.renderRoutingPanel();
    },

    renderRoutingSpecial: function(panel) {
        var self = this, status = this.routingData || {};
        while (panel.firstChild) panel.removeChild(panel.firstChild);
        var routerEnabled = (status.router === true || status.router === 1 || status.router === '1');
        var udp443Enabled = (status.udp443 === true || status.udp443 === 1 || status.udp443 === '1');
        var defs = {
            router: { title: _('Направлять исходящий трафик этого устройства через Mihomo'), detail: _('Применяется только к исходящим соединениям этого устройства — apk update, opkg update, wget, curl и тому подобное.'), enabled: routerEnabled, toggle: function() { self.confirmRouterRouting(!routerEnabled); } },
            udp443: { title: _('Блокировать QUIC (UDP/443)'), detail: _('Все устройства переходят на TCP вместо UDP (QUIC) на 443 порту, что упрощает маршрутизацию в Mihomo.'), enabled: udp443Enabled, toggle: function() { self.setUdp443(!udp443Enabled); } }
        };
        var grid = E('div', { class: 'mihomo-overview-cards' });
        this.getSpecialOrder().forEach(function(id) {
            var def = defs[id];
            var cardEl = E('div', { class: 'mihomo-overview-card ' + (def.enabled ? 'is-ok' : 'is-muted'), draggable: true }, [
                E('div', { class: 'mihomo-overview-card-head' }, E('div', { class: 'mihomo-overview-card-title' }, def.title)),
                E('div', { class: 'mihomo-overview-card-detail' }, def.detail),
                E('div', { class: 'mihomo-overview-card-actions' }, [
                    E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: def.toggle }, def.enabled ? _('Отключить') : _('Включить'))
                ])
            ]);
            cardEl.addEventListener('dragstart', function(ev) {
                self.specialDragId = id;
                cardEl.classList.add('mihomo-overview-dragging');
                try { ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', id); } catch (e) {}
            });
            cardEl.addEventListener('dragover', function(ev) { ev.preventDefault(); cardEl.classList.add('mihomo-overview-drag-over'); });
            cardEl.addEventListener('dragleave', function() { cardEl.classList.remove('mihomo-overview-drag-over'); });
            cardEl.addEventListener('drop', function(ev) {
                ev.preventDefault();
                cardEl.classList.remove('mihomo-overview-drag-over');
                var source = self.specialDragId || (ev.dataTransfer && ev.dataTransfer.getData('text/plain'));
                self.specialDragId = null;
                if (source) self.moveSpecialCard(source, id);
            });
            cardEl.addEventListener('dragend', function() { self.specialDragId = null; cardEl.classList.remove('mihomo-overview-dragging'); });
            grid.appendChild(cardEl);
        });
        panel.appendChild(grid);
    },
	
    getMihomoVersion: function() {
        return fs.stat('/usr/bin/mihomo')
            .then(function() { return fs.exec('/usr/bin/mihomo', ['--v']); })
            .then(function(res) {
                var output = ((res && res.stdout) || '') + '\n' + ((res && res.stderr) || '');
                if (res && res.code === 0 && output) {
                    var match = output.match(/\b(v\d+\.\d+\.\d+|alpha-[A-Za-z0-9._-]+)\b/i);
                    return match ? match[1] : 'Неизвестно';
                }
                return 'Неизвестно';
            })
            .catch(function(err) {
                console.error('Error getting version:', err);
                return 'Неизвестно';
            });
    },

    isMihomoVersionCurrent: function(latestVersion, currentVersion) {
        if (latestVersion === currentVersion) return true;
        return latestVersion === 'Prerelease-Alpha' && /^alpha-[A-Za-z0-9._-]+$/i.test(String(currentVersion || ''));
    },

    renderUpdateStatus: function(latestVersion, isManual) {
        var currentVersion = this.currentVersion || 'Неизвестно';
        this.latestVersion = latestVersion;

        var cleanCurrent = currentVersion.replace('v', '');
        var cleanLatest = latestVersion.replace('v', '');

        if (this.latestVersionEl) {
            this.latestVersionEl.style.display = 'inline';
            
            if (this.isMihomoVersionCurrent(latestVersion, currentVersion)) {
                this.latestVersionEl.textContent = '';
                this.latestVersionEl.style.color = ''; 
                this.latestVersionEl.style.opacity = '0.6';
                this.latestVersionEl.style.fontWeight = 'normal';
            } else {
                this.latestVersionEl.textContent = _('(доступна новая версия %s)').format(cleanLatest);
                this.latestVersionEl.style.color = '#5cb85c';
                this.latestVersionEl.style.opacity = '1';
            }
        }

        if (this.isMihomoVersionCurrent(latestVersion, currentVersion)) {
            this.updateButton.textContent = _('Проверить обновление');
            this.updateButton.className = 'btn cbi-button-neutral';
            this.updateButton.disabled = false;
            var self = this;
            this.updateButton.onclick = function() { self.checkForUpdates(true); };
            if (isManual) {
                ui.addNotification(null, E('p', _('Установлена самая актуальная версия')), 'info');
            }
        } else {
            this.updateButton.textContent = _('Установить обновление');
            this.updateButton.className = 'btn cbi-button-action';
            this.updateButton.disabled = false;
            this.updateButton.onclick = ui.createHandlerFn(this, 'handleUpdateMihomo');
        }
    },
	
	checkForUpdates: function(isManual, autoInstall) {
		var self = this;
        var channel = this.mihomoChannel || 'release';
        var CACHE_KEY = 'mihomo_update_cache_' + channel;
        var CACHE_TIME = 3600 * 1000;

        if (!isManual) {
            try {
                var cachedRaw = localStorage.getItem(CACHE_KEY);
                if (cachedRaw) {
                    var cached = JSON.parse(cachedRaw);
                    if (cached.version && (Date.now() - cached.timestamp < CACHE_TIME)) {
                        this.renderUpdateStatus(cached.version, false);
                        if (autoInstall && !this.isMihomoVersionCurrent(cached.version, this.currentVersion)) this.handleUpdateMihomo();
                        return;
                    }
                }
            } catch (e) {}
        }
		
        if (isManual && this.updateButton) {
            this.updateButton.disabled = true;
            this.updateButton.textContent = _('Проверка обновлений...');
        }
		
        var endpoint = channel === 'alpha' ? 'https://api.github.com/repos/MetaCubeX/mihomo/releases/tags/Prerelease-Alpha' : 'https://api.github.com/repos/MetaCubeX/mihomo/releases/latest';
		var cmd = 'wget -q -O - "' + endpoint + '" 2>/dev/null | grep -m1 \'"tag_name":\' | sed \'s/.*"\\(v[0-9.]*\\|Prerelease-Alpha\\)".*/\\1/\'';
		
		fs.exec('/bin/sh', ['-c', cmd])
			.then(function(res) {
				if (!res || typeof res !== 'object') throw new Error('Bad response');
				var latestVersion = (res.stdout || '').trim().replace(/["'\s]/g, '');
				if (!latestVersion || !latestVersion.match(/^(v\d+\.\d+\.\d+|Prerelease-Alpha)$/)) {
                    if (isManual) {
                        self.updateButton.disabled = false;
                        self.updateButton.textContent = _('Ошибка. Повторить обновление?');
                        self.updateButton.onclick = function() { self.checkForUpdates(true); };
                        ui.addNotification(null, E('p', _('Ошибка: ') + latestVersion), 'error');
                    }
				    return;
				}
                try { localStorage.setItem(CACHE_KEY, JSON.stringify({ version: latestVersion, timestamp: Date.now() })); } catch (e) {}
                self.renderUpdateStatus(latestVersion, isManual);
                if (autoInstall && !self.isMihomoVersionCurrent(latestVersion, self.currentVersion)) self.handleUpdateMihomo();
			})
			.catch(function(err) {
				if (isManual) {
                    self.updateButton.disabled = false;
                    self.updateButton.textContent = _('Ошибка. Повторить обновление?');
                    self.updateButton.onclick = function() { self.checkForUpdates(true); };
				    ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error');
				}
			});
	},
	
    createAutomaticBackup: function(component) {
        return callBackupStatus().then(function(status) {
            var settings = (status && status.settings) || {};
            var enabled = component === 'mihomo' ? settings.auto_mihomo : settings.auto_magitrickle;
            if (!enabled) return { ok: true, skipped: true };
            return callBackupCreate(component).then(function(result) {
                if (!result || !result.ok) throw new Error((result && result.error) || _('Не удалось создать автоматическую копию'));
                return result;
            });
        });
    },

    handleUpdateMihomo: function() {
		var self = this;
		var latestVersion = this.latestVersion;
        if (!latestVersion) return;
		this.updateButton.textContent = _('Ожидайте...');
		this.updateButton.disabled = true;
        if (this.mihomoChannelSelect) this.mihomoChannelSelect.disabled = true;
        if (this.overviewPanel) {
            var busyCard = this.overviewPanel.querySelector('[data-mihomo-card="mihomo"]');
            if (busyCard) {
                var busyBtns = busyCard.querySelectorAll('button');
                for (var bi = 0; bi < busyBtns.length; bi++) {
                    if (busyBtns[bi] !== this.updateButton) busyBtns[bi].disabled = true;
                }
            }
        }
        var arch;
        var steps;
        var detectArch = function() {
            var cmd = "case \"$(uname -m)\" in x86_64) grep -q avx2 /proc/cpuinfo 2>/dev/null && echo amd64 || echo amd64-compatible ;; aarch64|arm64) echo arm64 ;; armv7*) echo armv7 ;; i?86) echo 386 ;; riscv64) echo riscv64 ;; mips*) fpu=softfloat; grep -q FPU /proc/cpuinfo 2>/dev/null && fpu=hardfloat; endian=mips; [ \"$(hexdump -s 5 -n 1 -e '1/1 \\\"%d\\\"' /bin/busybox 2>/dev/null)\" = 1 ] && endian=mipsle; echo \"$endian-$fpu\" ;; *) exit 1 ;; esac";
            return fs.exec('/bin/sh', ['-c', cmd]).then(function(res) {
                arch = (res.stdout || '').trim();
                if (!arch) throw new Error(_('Не удалось определить архитектуру роутера'));
                return arch;
            });
        };
        var resolveDownloadUrl = function() {
            if (self.mihomoChannel !== 'alpha') return Promise.resolve('https://github.com/MetaCubeX/mihomo/releases/download/' + latestVersion + '/mihomo-linux-' + arch + '-' + latestVersion + '.gz');
            var cmd = 'wget -q -O - "https://api.github.com/repos/MetaCubeX/mihomo/releases/tags/Prerelease-Alpha" 2>/dev/null | tr -d "\\n" | grep -o \'"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*mihomo-linux-' + arch + '[^"]*\\.gz"\' | head -1 | sed \'s/.*"\\(https[^\"]*\\)".*/\\1/\'';
            return fs.exec('/bin/sh', ['-c', cmd]).then(function(res) {
                var url = (res.stdout || '').trim();
                if (!url) throw new Error(_('Не удалось найти архив Prerelease-Alpha'));
                return url;
            });
        };
        var executeStep = function(index) {
			if (index >= steps.length) {
                if (self.mihomoChannelSelect) self.mihomoChannelSelect.disabled = false;
				return self.getMihomoVersion().then(function(version) {
					self.currentVersion = version === 'Неизвестно' && self.mihomoChannel !== 'alpha' ? latestVersion : version;
                    self.renderUpdateStatus(self.currentVersion, false);
                    if (self.overviewPanel) {
                        var card = self.overviewPanel.querySelector('[data-mihomo-card="mihomo"] .mihomo-overview-card-title');
                        if (card) card.textContent = _('Mihomo') + ' ' + self.currentVersion;
                    }
                    return self.refreshOverview();
				});
			}
			return fs.exec('/bin/sh', ['-c', steps[index].shell])
				.then(function(res) {
					if (!res || res.code !== 0) throw new Error('Err: ' + (res ? res.code : 'unknown'));
					return executeStep(index + 1);
				});
		};
        self.createAutomaticBackup('mihomo').then(detectArch).then(resolveDownloadUrl).then(function(downloadUrl) {
            steps = [
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
            return executeStep(0);
        }).catch(function(err) {
            if (self.mihomoChannelSelect) self.mihomoChannelSelect.disabled = false;
            if (self.updateButton) {
                self.updateButton.textContent = _('Ошибка. Повторить обновление?');
                self.updateButton.disabled = false;
                self.updateButton.onclick = ui.createHandlerFn(self, 'handleUpdateMihomo');
            }
            ui.addNotification(null, E('p', _('Ошибка: %s').format(err.message)), 'error');
            if (self.overviewPanel && self.activeView === 'overview') self.refreshOverview();
            fs.exec('/bin/sh', ['-c', 'cp -f /tmp/mihomo.backup /usr/bin/mihomo && /etc/init.d/mihomo start']).catch(function() {});
        });
	},

	load: function() {
		return Promise.all([
            fs.read(MAIN_CONFIG).catch(function() { return ''; }),
            callServiceList('mihomo').catch(function() { return {}; }),
             fs.list(RULE_DIR).catch(function() { return []; }),
              fs.exec('/bin/sh', ['-c', 'service magitrickle status 2>&1; pidof magitrickled 2>/dev/null; true']).catch(function() { return { code: 1 }; }),
             fs.exec('/bin/sh', ['-c', 'if command -v timeout >/dev/null 2>&1; then timeout 5 magitrickled --version 2>&1; else magitrickled --version 2>&1; fi']).catch(function() { return { stdout: '' }; }),
             fs.read('/etc/mixomo/versions/magitrickle').catch(function() { return ''; })
		]);
	},
	
    render: function(data) {
		data = data || [];
        mainConfigContent = data[0] || '';
        var serviceInfo = data[1] || {};
        cachedRuleFiles = (data[2] || []);
        var magitrickleStatus = data[3] || {};
        var magitrickleOutput = ((data[4] && data[4].stdout) || '').replace(/\x1b\[[0-9;]*m/g, '');
         var magitrickleState = data[5] || '';
         var magitrickleVariant = (magitrickleState.match(/^([^\n\r]+)/) || ['',''])[1].trim();
         var magitrickleStored = magitrickleState.replace(/^[^\n]*\n/, '').trim();
         var magitrickleMatch = magitrickleOutput.match(/version[= ]+v?([0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*)/i);
        var magitrickleStoredMatch = magitrickleStored.match(/v?[0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*/);
        var magitrickleVersion = magitrickleStoredMatch ? magitrickleStoredMatch[0] : (magitrickleMatch ? 'v' + magitrickleMatch[1] : '');
        var isRunning = !!(serviceInfo.mihomo && serviceInfo.mihomo.instances.main.running);
        this.isRunning = isRunning;
        this.magitrickleRunning = isMagiRunningOutput(magitrickleStatus);
         this.magitrickleVersion = magitrickleVersion ? (magitrickleVersion.indexOf('v') === 0 ? magitrickleVersion : 'v' + magitrickleVersion) : _('Неизвестно');
         this.magitrickleVariant = magitrickleVariant === 'mod' ? 'mod' : 'original';
        
          var latestVersionEl = E('span', { 'id': 'mihomo-latest-version', 'style': 'margin-left: 4px; font-size: 0.9em; opacity: 0.7; display: none;' }, '');
          this.latestVersionEl = latestVersionEl;
          try { this.dashboardPanel = localStorage.getItem('mihomo_dashboard_panel') || ''; } catch (e) { this.dashboardPanel = ''; }
          if (this.dashboardPanel !== 'zashboard' && this.dashboardPanel !== 'metacubex') this.dashboardPanel = '';
         try { this.mihomoChannel = localStorage.getItem('mihomo_channel') === 'alpha' ? 'alpha' : 'release'; } catch (e) { this.mihomoChannel = 'release'; }
         var mihomoChannelSelect = E('select', { class: 'cbi-input-select', style: 'width:6rem; height:28px;', change: function(ev) {
             ev.stopPropagation();
             var previousChannel = self.mihomoChannel;
             var nextChannel = ev.target.value;
             if (!confirm(_('Переключить Mihomo на канал %s и установить его версию?').format(nextChannel === 'alpha' ? 'Prerelease' : 'Release'))) {
                 ev.target.value = previousChannel;
                 return;
             }
             self.mihomoChannel = nextChannel;
             try { localStorage.setItem('mihomo_channel', self.mihomoChannel); localStorage.removeItem('mihomo_update_cache_' + self.mihomoChannel); } catch (e) {}
             self.latestVersion = null;
             self.checkForUpdates(true, true);
         } }, [
             E('option', { value: 'release' }, _('Release')),
             E('option', { value: 'alpha' }, _('Prerelease'))
         ]);
         mihomoChannelSelect.value = this.mihomoChannel;
          this.mihomoChannelSelect = mihomoChannelSelect;
          var mihomoDashboardSelect = E('select', { class: 'cbi-input-select', style: 'width:6rem; height:28px;', change: function(ev) {
              ev.stopPropagation();
              var next = ev.target.value;
              self.dashboardPanel = (next === 'zashboard' || next === 'metacubex') ? next : '';
              try { localStorage.setItem('mihomo_dashboard_panel', self.dashboardPanel); } catch (e) {}
              if (editor && (currentFile === MAIN_CONFIG || currentFile.indexOf('/etc/mihomo/profiles/') === 0)) {
                  editor.setValue(applyMihomoDefaults(editor.getValue(), self.dashboardPanel), -1);
                  self.handleSaveAndApply(self.isRunning);
              }
          } }, [
              E('option', { value: '' }, '—'),
              E('option', { value: 'zashboard' }, 'Zashboard'),
              E('option', { value: 'metacubex' }, 'MetaCube')
          ]);
          mihomoDashboardSelect.value = this.dashboardPanel;
          this.mihomoDashboardSelect = mihomoDashboardSelect;
          var updateButton = E('button', { 'id': 'mihomo-update-btn', 'class': 'btn cbi-button-neutral', 'style': 'margin: 0;', 'disabled': true }, _('Проверить обновление'));
         this.updateButton = updateButton;
          var magitrickleUpdateButton = E('button', { 'id': 'magitrickle-update-btn', 'class': 'btn cbi-button-neutral mihomo-overview-card-action', 'disabled': true }, _('Проверить обновление'));
          this.magitrickleUpdateButton = magitrickleUpdateButton;
          this.mixomoBusy = false;
          this.mixomoVersion = null;
          this.mixomoAvailableSha = null;
          try { this.mixomoChannel = localStorage.getItem('mixomo_channel') === 'test' ? 'test' : 'stable'; } catch (e) { this.mixomoChannel = 'stable'; }
          var mixomoChannelSelect = E('select', { class: 'cbi-input-select', style: 'width:6rem; height:28px;', change: function(ev) {
              ev.stopPropagation();
              var previousChannel = self.mixomoChannel;
              var nextChannel = ev.target.value;
              if (!confirm(_('Переключить Mixomo на канал %s?').format(nextChannel === 'test' ? 'Prerelease' : 'Release'))) {
                  ev.target.value = previousChannel;
                  return;
              }
              self.mixomoChannel = nextChannel;
              try { localStorage.setItem('mixomo_channel', nextChannel); } catch (e) {}
              self.checkMixomoUpdates(true);
          } }, [
              E('option', { value: 'stable' }, _('Release')),
              E('option', { value: 'test' }, _('Prerelease'))
          ]);
          mixomoChannelSelect.value = this.mixomoChannel;
          this.mixomoChannelSelect = mixomoChannelSelect;
           var mixomoLanguageSelect = E('select', { class: 'cbi-input-select', style: 'width:6rem; height:28px;', change: function(ev) {
               ev.stopPropagation();
               try { localStorage.setItem('mixomo_language', ev.target.value); } catch (e) {}
               window.location.reload();
           } }, [
               E('option', { value: 'auto' }, _('Авто')),
               E('option', { value: 'ru' }, _('Русский')),
               E('option', { value: 'en' }, _('English'))
           ]);
           mixomoLanguageSelect.value = MIXOMO_LANGUAGE;
           this.mixomoLanguageSelect = mixomoLanguageSelect;
            var mixomoUpdateButton = E('button', { 'id': 'mixomo-update-btn', 'class': 'btn cbi-button-neutral', 'style': 'margin: 0;', 'disabled': true }, _('Проверить обновление'));
           this.mixomoUpdateButton = mixomoUpdateButton;
           var mixomoTitleVersion = E('span', { style: 'margin-left: 4px; font-size: 0.8em;' }, '');
           this.mixomoTitleVersion = mixomoTitleVersion;
          
          var header = E('div', { 'style': 'display: flex; align-items: center; margin-bottom: 1rem; flex-wrap: wrap;' }, [
               E('h2', { 'style': 'margin: 0;' }, [
                    E('span', { style: 'color:#00A66C;' }, 'Mix'), E('span', {}, 'omo'), mixomoTitleVersion
               ]),
              E('div', { 'style': 'display:flex; align-items:center; gap:0.35rem; margin-left:0.75rem;' }, [
                  mixomoUpdateButton, mixomoChannelSelect, mixomoLanguageSelect
              ])
         ]);
		
         var self = this;
          this.magitrickleUpdateButton.disabled = false;
          this.magitrickleUpdateButton.onclick = function(ev) { ev.stopPropagation(); self.checkMagiTrickleUpdates(true); };
          this.mixomoUpdateButton.disabled = false;
           this.mixomoUpdateButton.onclick = function(ev) { ev.stopPropagation(); self.checkMixomoUpdates(true); };
           this.getMixomoState().then(function(state) { self.mixomoVersion = state; self.setMixomoTitle(); });
           this.checkMixomoUpdates(false);
          this.getMihomoVersion().then(function(version) {
            self.currentVersion = version;
            var updateBtn = document.getElementById('mihomo-update-btn');
             if (updateBtn) {
                 updateBtn.disabled = false;
                 updateBtn.onclick = function() { self.checkForUpdates(true); }; 
             }
             if (self.overviewPanel && self.activeView === 'overview') self.refreshOverview();
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
             .btn, .cbi-button { height: 28px !important; min-height: 28px !important; display: inline-flex !important; align-items: center; justify-content: center; vertical-align: middle; }

             #output-text {
                font-size: 0.8rem !important;
            }
            .cbi-page-actions { display: none !important; }
            .custom-actions { display: flex; gap: 0.5rem; }
            .tab-bar { display: flex; flex-wrap: nowrap; background-color: var(--bg-tab); }
            .tab-item { display: flex; align-items: center; padding: 0.6em 1.2em; cursor: pointer; background-color: var(--bg-tab); color: var(--text-dim); margin-right: 1px; font-size: 0.9em; border-top: 1px solid transparent; white-space: nowrap; user-select: none; box-sizing: border-box }
            .tab-item:hover { background-color: var(--bg-toolbar); color: var(--text-main); }
            .tab-item.active { background-color: var(--bg-tab-active); color: var(--text-main); border: 1px solid var(--border-active); }
            .tab-close { margin-left: 0.6em; border-radius: 3px; padding: 0 0.3em; color: #999; font-weight: bold; }
            .tab-close:hover { background-color: #c0392b; color: white; }
            .tab-new { font-weight: bold; font-size: 1.2em; padding: 0.5em 0.8em; }
            .toolbar { background-color: transparent !important; border: 0 !important; padding: 0 !important; color: var(--text-main); }
            .toolbar.mihomo-rule-toolbar { border: 1px solid var(--border-color) !important; border-bottom: none !important; padding: .8rem !important; margin-bottom: 0 !important; }
            .toolbar-row { display: flex; gap: 0.8rem; align-items: center; }
            .toolbar textarea { width: 100%; height: 6em; background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 0.9em; padding: 0.4em; }
            .toolbar select { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: 0.4em; }
            .toolbar-col { display: flex; flex-direction: column; }

            .snippet-container { margin-top: 0; border: 0 !important; background: transparent !important; padding: 0 !important; display: none; }
             .mihomo-routing-panel { border: 0 !important; background: transparent !important; padding: 0 !important; margin: 0 0 1rem; }
             .mihomo-overview-panel, .mihomo-backup-panel { border: 0; background: transparent !important; padding: 0; margin: 0 0 1rem; }
             .mihomo-overview-intro { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border-color); padding-bottom: .7rem; margin-bottom: .7rem; }
             .mihomo-overview-row { display: block; margin-bottom: .7rem; }
             .mihomo-overview-cards { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: .7rem; }
.mihomo-overview-card { display: flex; flex-direction: column; padding: 1rem; border: 1px solid var(--border-color); border-left: 0; background: var(--bg-input); box-sizing: border-box; cursor: grab; }
              .mihomo-overview-card.is-ok { border-left: 3px solid #00A66C; }
              .mihomo-overview-card.is-muted { border-left: 1px solid var(--border-color); }
              .mihomo-overview-card-head { display: flex; align-items: center; justify-content: space-between; gap: .5rem; min-height: 1.65rem; }
             .mihomo-overview-card-title { color: inherit !important; font-size: 1.05em; font-weight: 600; }
             .mihomo-overview-card-head .btn { margin-left: 0 !important; }
               .mihomo-overview-card-detail { color: var(--text-dim); font-size: .98em; display: flex; flex-direction: column; gap: 0; }
              .mihomo-overview-card-detail > div { min-height: 1.65rem; display: flex; align-items: center; }
               .mihomo-overview-card-detail > div + div { padding-top: 0; }
             .mihomo-overview-card-value { color: inherit !important; font-size: 1.55em; font-weight: 600; margin: .8rem 0 .45rem; overflow-wrap: anywhere; }
              .mihomo-overview-card-actions { display: flex; justify-content: flex-start; gap: .5rem; margin-top: auto; padding-top: .8rem; }

              .mihomo-overview-card-actions .btn { margin-left: 0 !important; }
              .mihomo-overview-card-actions .mihomo-card-stop { margin-left: auto !important; }
                .mihomo-overview-card-action { height: 28px !important; font-size: .9em; white-space: nowrap; cursor: pointer; }
             .mihomo-overview-card-value .mihomo-overview-card-action { font-size: .58em; }



             .mihomo-overview-dragging { opacity: .55; }
             .mihomo-overview-drag-over { outline: 2px dashed var(--border-color); background-color: rgba(125,125,125,0.12); }
             @media (max-width: 700px) { .mihomo-overview-cards { grid-template-columns: 1fr; } }
              .mihomo-settings-row { display: flex; flex-wrap: wrap; }


             .mihomo-sub-row { padding: 0.1rem 0 0; background: transparent; background-image: none; }

            .mihomo-files-panel { border: 0 !important; background: transparent !important; padding: 0 !important; margin: 0 0 1rem; }
            .mihomo-edit-panel { border: 0 !important; background: transparent !important; padding: 0 !important; margin: 0 0 0.8rem; }
            .mihomo-file-active { font-weight: bold; color: #5cb85c !important; }
            .mihomo-dns-panel { border: 0 !important; background: transparent !important; padding: 0 !important; margin: 0 0 1rem; }
            .mihomo-seg { display: flex; flex-wrap: wrap; gap: 0.4rem; }

            .mihomo-dns-text { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 0.9em; padding: 0.6em; box-sizing: border-box; }
            .mihomo-dns-panel input[type=text] { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: .4em; }
             .mihomo-route-add { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; }
             .mihomo-route-add input:not([type=checkbox]), .mihomo-route-add select, .mihomo-files-panel input:not([type=checkbox]), .mihomo-files-panel select, .mihomo-dns-panel input:not([type=checkbox]), .mihomo-dns-panel select { width: 26rem; max-width: 100%; box-sizing: border-box; }
             .mihomo-route-add input[type=checkbox], .mihomo-files-panel input[type=checkbox], .mihomo-dns-panel input[type=checkbox] { width: auto; }
             .mihomo-day-box { display: block; }
             .mihomo-day-box label { display: flex; align-items: center; gap: .6rem; margin: .35rem 0; }
             .mihomo-day-box input, .mihomo-route-add label input, .mihomo-dns-panel label input { flex-shrink: 0; margin: 0; width: auto; }
             .mihomo-route-add > span, .mihomo-files-panel div > span { opacity: .75; }
             .mihomo-files-panel .mihomo-interval-select { width: 4.5rem; min-width: 4.5rem; }
             .mihomo-files-panel input:not([type=checkbox]), .mihomo-files-panel select { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: .4em; }

            .mihomo-route-actions { display: flex; gap: 1rem; padding: 0.2rem 0; }
            .mihomo-routing-panel input, .mihomo-routing-panel select { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: .4em; }
            .mihomo-routing-table th, .mihomo-routing-table td { text-align: left !important; }
            .mihomo-routing-table tbody tr:hover { background-color: rgba(125,125,125,0.15); }
            .mihomo-grip { width: 2.6rem; min-width: 2.6rem; text-align: center; cursor: grab; user-select: none; color: var(--text-dim); }
            .mihomo-table-heading { color: var(--text-dim); }
            .mihomo-grip:active { cursor: grabbing; }
            .mihomo-grip-handle { display: inline-flex; width: 2.2rem; height: 1.8rem; align-items: center; justify-content: center; box-sizing: border-box; border: 1px solid var(--border-color); border-radius: 4px; line-height: 1; cursor: grab; touch-action: none; }
            .mihomo-grip-handle:active { cursor: grabbing; }
            .mihomo-grip:hover .mihomo-grip-handle { background-color: rgba(125,125,125,0.2); color: var(--text-main); }
            .mihomo-dragging { opacity: .55; }
            .mihomo-drag-over { outline: 2px dashed var(--border-color); background-color: rgba(125,125,125,0.12); }
            .snippet-header { margin-bottom: 0.4rem; color: var(--text-main); font-size: 0.85em; }
            .snippet-text { width: 100%; height: 9.5em; background: var(--bg-tab-active); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 0.9em; padding: 0.8em; resize: none; }
            .output-box-close { background: transparent; border: none; color: var(--text-main); font-size: 1.5em; line-height: 1; cursor: pointer; margin-left: 1rem; padding: 0 0.4rem; }
            .output-box-close:hover { color: #e74c3c !important; }
			#ace_editor_container { width: 100%; height: 60vh; border: 1px solid var(--border-color); border-top: none; }
        `);
        
        var filesPanel = E('div', { 'id': 'mihomo-files-panel', 'class': 'mihomo-files-panel', 'style': 'display:none;' });
        this.filesPanel = filesPanel;
        var editPanel = E('div', { 'id': 'mihomo-edit-panel', 'class': 'mihomo-edit-panel', 'style': 'display:none;' });
        this.editPanel = editPanel;
        var editorFileBar = E('div', { 'id': 'mihomo-editor-file', 'style': 'display:none;' });
        this.editorFileBar = editorFileBar;
        var toolbarContainer = E('div', { 'id': 'mihomo-toolbar' });
        var editorContainer = E('div', { 'id': 'ace_editor_container' });
        
        var snippetContainer = E('div', { 'id': 'snippet-box', 'class': 'snippet-container', 'style': 'margin-top: 0.8rem' }, [
            E('div', { 'class': 'snippet-header', 'style': 'opacity: 0.7' }, _('Чтобы Mihomo увидел файл, добавьте эту секцию в rule-providers:')),
            E('textarea', { 'id': 'snippet-area', 'class': 'snippet-text', 'readonly': 'readonly', 'style': 'opacity: 0.8' }),
            E('div', { 'style': 'margin-top: 0.8rem; display: flex; gap: 0.6rem;' }, [
                E('button', { 'class': 'btn cbi-button-apply', 'click': ui.createHandlerFn(this, 'handleAutoAddSnippet') }, _('Добавить автоматически')),
                E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleCopySnippet') }, _('Скопировать текст'))
            ])
        ]);
        
        var buttonContainer = E('div', { 'id': 'bottom-buttons', 'class': 'custom-actions', 'style': 'margin-top: 1rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive', 'click': ui.createHandlerFn(this, 'handleSaveAndApply', isRunning) }, _('Сохранить')),
            E('button', { 'id': 'check-button', 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleCheck') }, _('Проверить конфигурацию')),
            E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleShowLogs') }, _('Показать журнал'))
        ]);
        
        var middleActions = E('div', { 'id': 'middle-actions', 'class': 'custom-actions', 'style': 'display: none; margin-top: 0.8rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive', 'click': ui.createHandlerFn(this, 'handleSaveAndApply', isRunning) }, _('Сохранить'))
        ]);

        var profileActions = E('div', { 'id': 'profile-actions', 'class': 'custom-actions', 'style': 'display: none; margin-top: 0.8rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive', 'click': ui.createHandlerFn(this, 'handleSaveAndApply', isRunning) }, _('Сохранить')),
            E('button', { 'id': 'profile-check-button', 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleCheck') }, _('Проверить конфигурацию')),
            E('button', { 'id': 'profile-logs-button', 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleShowLogs') }, _('Показать журнал'))
        ]);
        
        var outputBox = E('div', { 'id': 'output-box', 'style': 'display: none; margin-top: 1.2rem; border: 1px solid var(--border-color); border-radius: 4px; overflow: hidden;' }, [
            E('div', { 'style': 'background: var(--bg-output-header); color: var(--text-output); padding: 0.6rem 0.8rem; border-bottom: 1px solid var(--border-color); display: flex; align-items: center;' }, [
                E('strong', { 'style': 'font-size: 0.9em' }, _('Вывод:')),
                E('button', { 'class': 'output-box-close', 'click': function() { document.getElementById('output-box').style.display = 'none'; } }, '×')
            ]),
            E('pre', { 'id': 'output-text', 'style': 'margin: 0; padding: 1rem; background: var(--bg-output); color: var(--text-output); font-family: monospace; font-size: 1em; white-space: pre-wrap; word-wrap: break-word; max-height: 25rem; overflow-y: auto;' }, '')
        ]);

        var overviewPanel = E('div', { 'class': 'mihomo-overview-panel', 'style': 'display:none;' });
        this.overviewPanel = overviewPanel;

        var settingsRow = E('ul', { 'class': 'cbi-tabmenu mihomo-settings-row', 'style': 'margin-bottom: 0.3rem;' });
        this.settingsRow = settingsRow;
        this.renderSettingsRow();

        var subRow = E('ul', { 'class': 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', 'style': 'margin-bottom: 0.5rem;' });
        this.subRow = subRow;
        this.renderSubRow();

        var thirdRow = E('ul', { 'class': 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', 'style': 'margin-bottom: 0.5rem; display:none;' });
         this.thirdRow = thirdRow;
         this.renderThirdRow();

         var fourthRow = E('ul', { 'class': 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', 'style': 'margin-bottom: 0.5rem; display:none;' });
         this.fourthRow = fourthRow;
         this.renderFourthRow();

         var routingPanel = E('div', { 'class': 'mihomo-routing-panel', 'style': 'display:none;' });
        this.routingPanel = routingPanel;

        var dnsModeRow = E('ul', { 'class': 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', 'style': 'display:none; margin-bottom: 0.5rem;' });
        this.dnsModeRow = dnsModeRow;

        var dnsPanel = E('div', { 'class': 'mihomo-dns-panel', 'style': 'display:none;' });
        this.dnsPanel = dnsPanel;

         var schedulePanel = E('div', { 'class': 'mihomo-dns-panel', 'style': 'display:none;' });
         this.schedulePanel = schedulePanel;

         var magitricklePanel = E('div', { 'class': 'mihomo-magitrickle-panel', 'style': 'display:none;' }, E('iframe', {
             src: 'http://' + window.location.hostname + ':8080',
             style: 'width:100%; height:80vh; border:0;'
         }));
         this.magitricklePanel = magitricklePanel;

          var backupPanel = E('div', { 'class': 'mihomo-backup-panel', 'style': 'display:none;' });
          this.backupPanel = backupPanel;
         
         loadScript(ACE_DIR + 'ace.js').then(function() {
            ace.config.set('basePath', ACE_DIR);
            editor = ace.edit("ace_editor_container");
            var theme = isDark ? "ace/theme/merbivore_soft" : "ace/theme/tomorrow";
            editor.setTheme(theme);
            editor.session.setMode("ace/mode/yaml");
            editor.setOptions({ 
				fontSize: "0.95em", 
				showPrintMargin: false, 
				wrap: true, 
				tabSize: 2, 
				useSoftTabs: true,
				highlightActiveLine: false
			});
            editor.setValue(mainConfigContent, -1);
            setTimeout(function() { editor.resize(); }, 100);
        }).catch(console.error);
        
         this.renderSettingsRow();
         this.refreshProfiles();
         this.startStatusRefresh();
         this.renderToolbar(toolbarContainer, currentFile);
        setTimeout(function() { this.showViewContent(); }.bind(this), 100);
        
        return E('div', { 'class': 'cbi-map' }, [
             header, settingsRow, subRow, thirdRow, fourthRow, overviewPanel, magitricklePanel, backupPanel, routingPanel, dnsModeRow, dnsPanel, schedulePanel, style, filesPanel, editPanel, editorFileBar, toolbarContainer, editorContainer,
            middleActions, profileActions, snippetContainer, buttonContainer, outputBox
        ]);
    },
    
    renderEditorFileBar: function(filePath) {
        var bar = document.getElementById('mihomo-editor-file') || this.editorFileBar;
        if (!bar) return;
        if (!filePath) { bar.style.display = 'none'; return; }
        var self = this;
        var base = String(filePath).split('/').pop() || filePath;
        L.dom.content(bar, [
            E('strong', { 'style': 'font-size:1.05em; font-weight:600; overflow-wrap:anywhere;' }, base),
            E('span', { 'style': 'color:var(--text-dim); font-size:.98em; overflow-wrap:anywhere;' }, filePath),
            E('button', { 'class': 'output-box-close', 'style': 'margin-left:auto;', 'click': function() { editorRequested = false; self.updateVisibility(currentFile); } }, '×')
        ]);
    },

    updateVisibility: function(filePath) {
        var isMain = (filePath === MAIN_CONFIG);
        var isProfile = filePath.indexOf('/etc/mihomo/profiles/') === 0 && filePath.endsWith('.yaml');
        var isConfigList = this.activeView === 'configs' && this.activeSub === 'list';
        var isRulesList = (this.activeView === 'rules' && this.activeSub === 'list') || (this.activeView === 'configs' && this.activeSub === 'rules' && this.activeThird === 'list');
        var isConfigFile = isMain || filePath.indexOf('/etc/mihomo/profiles/') === 0;
        var isRuleFile = filePath.indexOf(RULE_DIR) === 0;
         var editorVisible = editorRequested && ((isConfigList && isConfigFile) || (isRulesList && isRuleFile));
        var editorContainer = document.getElementById('ace_editor_container');
        var toolbar = document.getElementById('mihomo-toolbar');
        var bottomButtons = document.getElementById('bottom-buttons');
        var middleActions = document.getElementById('middle-actions');
        var profileActions = document.getElementById('profile-actions');
        var outputBox = document.getElementById('output-box');
        var fileBar = document.getElementById('mihomo-editor-file') || this.editorFileBar;

        if (fileBar) {
            if (editorVisible) {
                this.renderEditorFileBar(filePath);
                fileBar.style.display = 'flex';
                fileBar.style.alignItems = 'center';
                fileBar.style.gap = '.6rem';
                fileBar.style.flexWrap = 'wrap';
                fileBar.style.padding = '.6rem .8rem';
                fileBar.style.border = '1px solid var(--border-color)';
                fileBar.style.borderBottom = 'none';
                fileBar.style.background = 'var(--bg-input)';
                fileBar.style.color = '';
            } else {
                fileBar.style.display = 'none';
            }
        }
        editorContainer.style.display = editorVisible ? 'block' : 'none';
        toolbar.style.display = editorVisible && isRuleFile ? 'block' : 'none';
        bottomButtons.style.display = editorVisible && isMain ? 'flex' : 'none';
        middleActions.style.display = editorVisible && isRulesList ? 'flex' : 'none';
        var showProfileActions = editorVisible && isConfigList && isProfile;
        profileActions.style.display = showProfileActions ? 'flex' : 'none';
        if (!editorVisible) outputBox.style.display = 'none';

        var snippetBox = document.getElementById('snippet-box');
        if (!editorVisible || isMain || !isRuleFile) {
            snippetBox.style.display = 'none';
            if (editorVisible && editor) setTimeout(function() { editor.resize(); }, 0);
            return;
        }
        var baseName = filePath.split('/').pop().replace(/\.(yaml|txt)$/, '');
        var providerName = baseName + '-list:';
        if (mainConfigContent.includes(providerName)) {
            snippetBox.style.display = 'none';
        } else {
            document.getElementById('snippet-area').value = generateProviderSnippet(filePath);
            snippetBox.style.display = 'block';
        }
        if (editorVisible && editor) setTimeout(function() { editor.resize(); }, 0);
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
			return fs.write(MAIN_CONFIG, newContent).then(function() { return normalizeEditorConfig(MAIN_CONFIG); });
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
        if (filePath === MAIN_CONFIG || filePath.indexOf(RULE_DIR) !== 0) { container.style.display = 'none'; return; }
        
        container.style.display = 'block';
        container.className = 'toolbar mihomo-rule-toolbar';
        var self = this;
        
        if (filePath.endsWith('.txt')) {
            var input = E('textarea', { 'placeholder': 'google.com\nyoutube.com' });
            var suffixCheck = E('input', { 'type': 'checkbox', 'id': 'suffixCheck', 'checked': true });
            
			var row = E('div', { 'class': 'toolbar-row' }, [
				E('div', { 'style': 'flex-grow: 1;' }, input),
				E('div', { 'class': 'toolbar-col', 'style': 'min-width: 10rem; display: flex; flex-direction: column; justify-content: space-between;' }, [
					E('label', { 'for': 'suffixCheck', 'style': 'align-self: flex-start; font-size: 0.85em;' }, [ suffixCheck, ' . (дубликаты с точкой)' ]),
					E('button', { 'class': 'btn cbi-button-positive', 'style': 'align-self: center;', 'click': function() { self.handleAppendList(input.value, suffixCheck.checked); input.value = ''; } }, _('Добавить'))
				])
			]);
            container.appendChild(row);
        } else {
            var input = E('textarea', { 'placeholder': 'google.com\n104.28.0.0/16\n*.example.com' });
            var typeSelect = E('select', { 'style': 'font-size: 0.9em' }, [
                E('option', { 'value': 'Auto' }, 'Auto'),
                E('option', { 'value': 'DOMAIN-SUFFIX' }, 'DOMAIN-SUFFIX'),
                E('option', { 'value': 'DOMAIN' }, 'DOMAIN'),
                E('option', { 'value': 'DOMAIN-KEYWORD' }, 'DOMAIN-KEYWORD'),
                E('option', { 'value': 'DOMAIN-WILDCARD' }, 'DOMAIN-WILDCARD'),
                E('option', { 'value': 'DOMAIN-REGEX' }, 'DOMAIN-REGEX'),
                E('option', { 'value': 'IP-CIDR' }, 'IP-CIDR'),
                E('option', { 'value': 'IP-CIDR6' }, 'IP-CIDR6')
            ]);
            var row = E('div', { 'class': 'toolbar-row' }, [
                E('div', { 'style': 'flex-grow: 1;' }, input),
                E('div', { 'class': 'toolbar-col' }, [ typeSelect ]),
                E('div', { 'class': 'toolbar-col', 'style': 'min-width: 8rem; justify-content: flex-end;' }, [
                    E('button', { 'class': 'btn cbi-button-positive', 'click': function() { self.handleGenerateRules(input.value, typeSelect.value); input.value = ''; } }, _('Создать'))
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
    
    renderFilesPanel: function(container) {
        if (!container) return;
        if (this.activeView === 'rules') {
            if (this.activeSub === 'add') {
                this.renderRulesAdd(container);
            } else {
                this.renderRulesList(container);
            }
         } else if (this.activeView === 'configs' && this.activeSub === 'rules') {
             if (this.activeThird === 'add') {
                 this.renderRulesAdd(container);
             } else {
                 this.renderRulesList(container);
             }
         } else {
             if (this.activeThird === 'add') {
                 this.renderConfigsAdd(container);
             } else {
                 this.renderConfigsList(container);
             }
         }
    },

    mkIntervalSelect: function(type, name, current) {
        var self = this;
        current = (current || '');
        var presets = [0, 1, 3, 6, 12, 24];
        var isCustom = (current !== '' && presets.indexOf(parseInt(current, 10)) === -1);
         var opts = presets.map(function(h) {
             return E('option', { value: String(h) }, h === 0 ? _('Без обновлений') : self.hoursPrefixLabel(h));
         });
        if (isCustom) opts.push(E('option', { value: String(parseInt(current, 10)) }, self.updateHoursLabel(current)));
         var sel = E('select', { class: 'mihomo-interval-select', style: 'width:4.5rem; min-width:4.5rem;' }, opts);
        var input = E('input', { type: 'number', min: '1', max: '8760', style: 'width:4.5rem; display:none;' });
        sel.value = isCustom ? String(parseInt(current, 10)) : current;
        input.value = '';
        input.style.display = 'none';
        var apply = function() {
            var v = sel.value;
            if (v === 'custom') {
                var n = input.value.trim();
                if (!n || parseInt(n, 10) < 1 || parseInt(n, 10) > 8760) {
                    ui.addNotification(null, E('p', _('Интервал от 1 до 8760 часов')), 'error');
                    return;
                }
                v = String(parseInt(n, 10));
            }
            callSetInterval(type, name, v).then(function(res) { self.showRoutingError(res); });
        };
        sel.addEventListener('change', function() {
            if (sel.value === 'custom') {
                input.style.display = 'inline-block';
                if (!input.value) input.value = '12';
            } else {
                input.style.display = 'none';
                apply();
            }
        });
        input.addEventListener('change', apply);
        var wrap = E('div', { style: 'display:flex; align-items:center; gap:.3rem;' });
        wrap.appendChild(sel);
        wrap.appendChild(input);
        return wrap;
    },

     hoursLabel: function(value) {
         var n = parseInt(value, 10);
         if (n % 10 === 1 && n % 100 !== 11) return n + ' ' + _('час');
         if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return n + ' ' + _('часа');
         return n + ' ' + _('часов');
     },

      hoursPrefixLabel: function(value) {
          var n = parseInt(value, 10);
          if (n === 1) return _('Каждый') + ' ' + _('час');
          var prefix = n % 10 === 1 && n % 100 !== 11 ? _('Каждый') : _('Каждые');
          return prefix + ' ' + this.hoursLabel(n);
      },

     updateHoursLabel: function(value) {
         return _('Обновление') + ' ' + this.hoursPrefixLabel(value).toLowerCase();
     },

     mkIntervalEditor: function() {
         var self = this;
         var presets = [0, 1, 3, 6, 12, 24];
        var opts = presets.map(function(h) {
            return E('option', { value: String(h) }, h === 0 ? _('Без обновлений') : self.hoursPrefixLabel(h));
        });
        opts.push(E('option', { value: 'custom' }, _('Свой интервал в часах')));
        var sel = E('select', { style: 'min-width:8rem;' }, opts);
        var input = E('input', { type: 'number', min: '1', max: '8760', style: 'width:4.5rem; display:none;' });
        sel.value = '0';
        sel.addEventListener('change', function() {
            input.style.display = sel.value === 'custom' ? 'inline-block' : 'none';
            if (sel.value === 'custom' && !input.value) input.value = '12';
        });
        var wrap = E('div', { style: 'display:flex; align-items:center; gap:.3rem;' }, [sel, input]);
        return {
            element: wrap,
            value: function() {
                if (sel.value !== 'custom') return sel.value;
                var n = input.value.trim();
                if (!n || parseInt(n, 10) < 1 || parseInt(n, 10) > 8760) {
                    ui.addNotification(null, E('p', _('Интервал от 1 до 8760 часов')), 'error');
                    return null;
                }
                return String(parseInt(n, 10));
            }
        };
    },

    mkFilePicker: function(accept) {
        var input = E('input', { type: 'file', accept: accept, style: 'display:none;' });
        var label = E('span', {}, _('Загрузить файл'));
        var btn = E('button', { 'class': 'btn cbi-button-neutral', click: function() { input.click(); } }, label);
        input.addEventListener('change', function() {
            label.textContent = input.files && input.files[0] ? input.files[0].name : _('Загрузить файл');
        });
        return { input: input, btn: btn };
    },

    mkMoveGroup: function(opts) {
        var self = this;
        var grip = E('span', { class: 'mihomo-grip-handle', draggable: true, title: _('Перетащить'), style: 'display:inline-flex; align-items:center; justify-content:center; line-height:1; padding:0 .35rem;' }, '≡');
        var up = E('button', { 'class': 'btn cbi-button-neutral', title: _('Вверх'), click: opts.up }, '↑');
        var down = E('button', { 'class': 'btn cbi-button-neutral', title: _('Вниз'), click: opts.down }, '↓');
        var ctrl = E('div', { class: 'mihomo-route-actions', style: 'gap:.4rem; align-items:center; margin-right:.5rem;' }, [grip, up, down]);
        var clearDragVisual = function() {
            if (self.dragRow && self.dragRow.classList) self.dragRow.classList.remove('mihomo-dragging');
            if (self.dragTargetRow && self.dragTargetRow.classList) self.dragTargetRow.classList.remove('mihomo-drag-over');
            self.dragRow = null;
            self.dragTargetRow = null;
        };
        var moveTo = function(target) {
            var source = self.dragSource;
            if (source === null || isNaN(source) || source < 0 || source >= opts.arr.length) { clearDragVisual(); return; }
            if (source === target) { self.dragSource = null; clearDragVisual(); return; }
            var item = opts.arr.splice(source, 1)[0];
            if (source < target) target--;
            opts.arr.splice(target, 0, item);
            self.dragSource = null;
            clearDragVisual();
            opts.onChange();
        };
        grip.addEventListener('dragstart', function(ev) {
            self.dragSource = opts.dragIndex;
            self.dragRow = opts.row;
            if (opts.row.classList) opts.row.classList.add('mihomo-dragging');
            try {
                ev.dataTransfer.effectAllowed = 'move';
                ev.dataTransfer.setData('text/plain', String(opts.dragIndex));
            } catch(e) {}
        });
        grip.addEventListener('dragend', function() { self.dragSource = null; clearDragVisual(); });
        grip.addEventListener('pointerdown', function(ev) {
            if (ev.button !== 0) return;
            ev.preventDefault();
            self.dragSource = opts.dragIndex;
            self.dragTarget = null;
            self.dragRow = opts.row;
            if (opts.row.classList) opts.row.classList.add('mihomo-dragging');
        });
        grip.addEventListener('mousedown', function(ev) {
            if (ev.button !== 0) return;
            ev.preventDefault();
            self.dragSource = opts.dragIndex;
            self.dragTarget = null;
            self.dragRow = opts.row;
            if (opts.row.classList) opts.row.classList.add('mihomo-dragging');
        });
        opts.row.addEventListener('mouseenter', function() {
            if (self.dragSource !== null) {
                self.dragTarget = opts.dragIndex;
                if (self.dragTargetRow && self.dragTargetRow !== opts.row && self.dragTargetRow.classList) self.dragTargetRow.classList.remove('mihomo-drag-over');
                self.dragTargetRow = opts.row;
                if (opts.row.classList) opts.row.classList.add('mihomo-drag-over');
            }
        });
        document.addEventListener('mouseup', function(ev) {
            if (self.dragSource === null) return;
            ev.preventDefault();
            if (self.dragTarget === null) {
                self.dragSource = null;
                clearDragVisual();
                return;
            }
            moveTo(self.dragTarget);
            self.dragTarget = null;
        });
        opts.row.addEventListener('dragover', function(ev) { if (ev.preventDefault) ev.preventDefault(); });
        opts.row.addEventListener('drop', function(ev) {
            ev.preventDefault();
            var source = self.dragSource;
            if (source === null && ev.dataTransfer) source = parseInt(ev.dataTransfer.getData('text/plain'), 10);
            self.dragSource = source;
            moveTo(opts.dragIndex);
        });
        opts.row.addEventListener('pointerup', function(ev) {
            if (self.dragSource === null) return;
            ev.preventDefault();
            moveTo(opts.dragIndex);
        });
        return ctrl;
    },

    moveRow: function(arr, idx, dir) {
        var j = idx + dir;
        if (j < 0 || j >= arr.length) return;
        var tmp = arr[idx]; arr[idx] = arr[j]; arr[j] = tmp;
    },

    persistOrder: function(list, names) {
        var self = this;
        callSetOrder(list, names.join('\n') + '\n').then(function(res) {
            if (self.showRoutingError(res)) {
                if (list === 'configs' || list === 'rules') {
                    self.refreshProfiles();
                } else {
                    self.refreshSchedule();
                }
            }
        }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
    },

     updateConfigCardStates: function(active) {
         if (!this.filesPanel) return;
         var cards = this.filesPanel.querySelectorAll('[data-config-name]');
         for (var i = 0; i < cards.length; i++) {
             var card = cards[i];
             var isActive = card.getAttribute('data-config-name') === active;
             card.classList.toggle('is-ok', isActive);
             card.classList.toggle('is-muted', !isActive);
         }
     },

     startStatusRefresh: function() {
         var self = this;
         if (this.statusRefreshTimer) return;
         this.statusRefreshTimer = setInterval(function() {
             if (document.hidden) return;
             callScheduleList().then(function(schedule) {
                 if (!schedule || schedule.ok !== true) return;
                 var time = schedule.time || [];
                 var trigger = schedule.trigger || [];
                 var enabled = time.some(function(item) { return item.enabled === true || item.enabled === 1 || item.enabled === '1'; }) || trigger.some(function(item) { return item.enabled === true || item.enabled === 1 || item.enabled === '1'; });
                 if (!enabled) return;
                 return callProfilesList();
             }).then(function(res) {
                 if (!res || res.ok !== true) return;
                 self.profilesData = res;
                 if (self.activeView === 'configs' && self.activeSub === 'list' && self.activeThird === 'list') self.updateConfigCardStates(res.active || '');
                 if (self.activeView === 'overview' && !self.magitrickleBusy && !self.mixomoBusy) self.refreshOverview();
             });
         }, 60000);
     },

     refreshProfiles: function() {
         var self = this;
         return callProfilesList().then(function(res) {
            if (!res || res.ok !== true) { self.showRoutingError(res || { ok: false, error: _('Не удалось получить профили') }); return; }
            self.profilesData = res;
            var cOrder = res.configsOrder || [];
            if (cOrder.length) {
                self.configsOrderArr = cOrder.slice();
            } else if (!self.configsOrderArr || !self.configsOrderArr.length) {
                self.configsOrderArr = (res.profiles || []).map(function(p) { return p.name; });
            }
            var rOrder = res.rulesOrder || [];
            if (rOrder.length) {
                self.rulesOrderArr = rOrder.slice();
            } else {
                self.rulesOrderArr = (cachedRuleFiles || []).filter(function(f) { return f.type === 'file'; }).map(function(f) { return f.name; });
            }
            self.renderFilesPanel(document.getElementById('mihomo-files-panel'));
        }).catch(function(err) { ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
    },

    renderConfigsAdd: function(container) {
        L.dom.content(container, []);
        var self = this;
        var sections = ['proxies', 'proxy-groups', 'proxy-providers', 'rule-providers', 'rules'];
        var inStyle = 'width:100%; max-width:26rem;';
         container.appendChild(E('div', { style: 'margin:.5rem 0 1rem;' }, [
             E('button', { class: 'btn cbi-button-neutral', click: function() { self.switchSub('list'); } }, '← ' + _('Все конфигурации'))
         ]));

         container.appendChild(E('button', { class: 'mihomo-config-section-title btn cbi-button-neutral' }, _('Локально')));
         var lName = E('input', { type: 'text', style: inStyle });
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Название'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [lName]));
         var lCopy = E('input', { type: 'checkbox' });
         container.appendChild(E('div', { style: 'margin:.5rem 0 .2rem;' }, [E('span', {}, _('Необязательно'))]));
          
         var copyRow = E('div', { style: 'margin:.3rem 0;' }, [E('label', { style: 'display:flex; align-items:center; gap:.6rem;' }, [lCopy, E('span', {}, _('Скопировать активную конфигурацию'))])]);
        container.appendChild(copyRow);
        var lPick = this.mkFilePicker('.yaml,.yml,.txt');
        
        var uploadOptional = E('div', { style: 'margin:.5rem 0 .2rem;' }, [E('span', {}, _('Необязательно'))]);
         container.appendChild(uploadOptional);
         var uploadRow = E('div', { style: 'margin:.3rem 0;' }, [lPick.btn]);
        container.appendChild(uploadRow);
         lCopy.addEventListener('change', function() {
             uploadRow.style.display = lCopy.checked ? 'none' : 'block';
             uploadOptional.style.display = lCopy.checked ? 'none' : 'block';
         });
        lPick.input.addEventListener('change', function() {
            if (lPick.input.files && lPick.input.files[0]) {
                 lCopy.checked = false;
                 copyRow.style.display = 'none';
                 uploadOptional.style.display = 'none';
            }
        });
        container.appendChild(E('div', { style: 'margin:.5rem 0;' }, [
            E('button', { 'class': 'btn cbi-button-positive', click: function() {
                var nm = lName.value.trim();
                var file = lPick.input.files && lPick.input.files[0];
                if (file) {
                    if (!nm) { nm = file.name.replace(/\.(yaml|yml|txt)$/i, ''); }
                    if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                    if (nm === 'config') { ui.addNotification(null, E('p', _('Имя config зарезервировано Mihomo')), 'error'); return; }
                    var reader = new FileReader();
                    reader.onload = function() {
                        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Создание...'))]);
                        callProfilesImportFull(nm, '', reader.result).then(function(res) {
                            ui.hideModal();
                            if (self.showRoutingError(res)) { ui.addNotification(null, E('p', _('Конфигурация создана. Для просмотра нажмите «Все конфигурации».')), 'info'); self.refreshProfiles(); }
                        }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                    };
                    reader.readAsText(file);
                } else {
                    if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                    if (nm === 'config') { ui.addNotification(null, E('p', _('Имя config зарезервировано Mihomo')), 'error'); return; }
                    ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Создание...'))]);
                    callProfilesCreate(nm, lCopy.checked).then(function(res) {
                        ui.hideModal();
                        if (self.showRoutingError(res)) { ui.addNotification(null, E('p', _('Конфигурация создана. Для просмотра нажмите «Все конфигурации».')), 'info'); self.refreshProfiles(); }
                    }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                }
              }}, _('Создать'))
          ]));
 
           container.appendChild(E('button', { class: 'mihomo-config-section-title btn cbi-button-neutral' }, _('Онлайн')));
         var oName = E('input', { type: 'text', style: inStyle });
         container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Название'))]));
         container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [oName]));
         var oUrl = E('input', { type: 'text', placeholder: '', style: inStyle });
         container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Ссылка'))]));
         container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [oUrl]));
         var oInterval = this.mkIntervalEditor();
         container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Обновление'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [oInterval.element]));
        container.appendChild(E('p', { style: 'opacity:.8; margin:.5rem 0 .3rem;' }, _('Сохранить следующие блоки:')));
        var secCbs = {};
        sections.forEach(function(s) {
            var cb = E('input', { type: 'checkbox', 'checked': true });
            secCbs[s] = cb;
            container.appendChild(E('div', { style: 'margin:.2rem 0;' }, [E('label', { style: 'display:flex; align-items:center; gap:.6rem;' }, [cb, E('span', {}, s)])]));
        });
         container.appendChild(E('div', { style: 'margin:.5rem 0;' }, [
             E('button', { 'class': 'btn cbi-button-positive', click: function() {
                  var nm = oName.value.trim();
                  if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                  if (nm === 'config') { ui.addNotification(null, E('p', _('Имя config зарезервировано Mihomo')), 'error'); return; }
                  var url = oUrl.value.trim();
                  if (!url) { ui.addNotification(null, E('p', _('Укажите ссылку')), 'error'); return; }
                  var interval = oInterval.value();
                  if (interval === null) return;
                  var sel = sections.filter(function(s) { return secCbs[s].checked; });
                 if (!sel.length) { ui.addNotification(null, E('p', _('Выберите хотя бы одну секцию')), 'error'); return; }
                 ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Импорт...'))]);
                 callProfilesImport(nm, url, '', sel.join(','), interval).then(function(res) {
                     ui.hideModal();
                     if (self.showRoutingError(res)) { ui.addNotification(null, E('p', _('Конфигурация создана. Для просмотра нажмите «Все конфигурации».')), 'info'); self.refreshProfiles(); }
                 }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
             }}, _('Импортировать'))
         ]));
         var configNodes = [];
         while (container.firstChild) configNodes.push(container.removeChild(container.firstChild));
          var configSections = [];
          var configTitles = [];
          var configSection = null;
          configNodes.forEach(function(node) {
              if (node.classList && node.classList.contains('mihomo-config-section-title')) {
                 configSection = E('div', { style: 'margin-top:1rem;' });
                 configSections.push(configSection);
                 configTitles.push(node.textContent);
             } else if (configSection) {
                 configSection.appendChild(node);
             }
         });
         var configButtons = E('ul', { class: 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', style: 'margin:.5rem 0 1rem;' });
          configTitles.forEach(function(title, idx) {
              configButtons.appendChild(makeLuciTab(_(title), idx === 0, function() {
                  var isOpen = configSections[idx].style.display !== 'none';
                  configSections.forEach(function(section) { section.style.display = 'none'; });
                  Array.prototype.forEach.call(configButtons.children, function(tab) { tab.classList.add('cbi-tab-disabled'); });
                  if (!isOpen) {
                      configSections[idx].style.display = 'block';
                      configButtons.children[idx].classList.remove('cbi-tab-disabled');
                  }
              }));
          });
         container.appendChild(configButtons);
         configSections.forEach(function(section, idx) { section.style.display = idx === 0 ? 'block' : 'none'; container.appendChild(section); });
     },

     toggleConfigEditor: function(path) {
         if (currentFile === path && editorRequested) {
             editorRequested = false;
             this.updateVisibility(path);
             return;
         }
         this.handleSelectFile(path);
         var ed = document.getElementById('ace_editor_container');
         if (ed && ed.scrollIntoView) ed.scrollIntoView({ block: 'start' });
     },

     openConfigCardEdit: function(cardEl, profile, path) {
         var self = this;
         var actions = cardEl.querySelector('.mihomo-overview-card-actions');
         if (!actions || cardEl.querySelector('.mihomo-config-card-edit')) return;
         actions.style.display = 'none';
          var name = E('input', { type: 'text', value: profile.name + '.yaml', style: 'width:100%; box-sizing:border-box;' });
         var url = E('input', { type: 'text', value: profile.url || '', style: 'width:100%; box-sizing:border-box;', placeholder: _('Укажите ссылку') });
          var interval = this.mkIntervalEditor();
          var intervalSelect = interval.element.querySelector('select');
          var profileInterval = String(profile.interval || '0');
          if (profileInterval !== '0' && ['1', '3', '6', '12', '24'].indexOf(profileInterval) === -1) intervalSelect.appendChild(E('option', { value: profileInterval }, self.hoursLabel(profileInterval)));
          intervalSelect.value = profileInterval;
          var head = cardEl.querySelector('.mihomo-overview-card-head');
          var detailBox = cardEl.querySelector('.mihomo-overview-card-detail');
          if (head) head.style.display = 'none';
          if (detailBox) detailBox.style.display = 'none';
          var localBtn;
          var onlineBtn;
          var online = !!profile.url;
          var urlField;
          var intervalField;
          var localStatus;
          var setMode = function(isOnline) {
              online = isOnline;
              localBtn.classList.toggle('cbi-tab-disabled', online);
              onlineBtn.classList.toggle('cbi-tab-disabled', !online);
              urlField.style.display = online ? 'block' : 'none';
              intervalField.style.display = online ? 'block' : 'none';
              localStatus.style.display = online ? 'none' : 'block';
          };
          localBtn = makeLuciTab(_('Локально'), !online, function() { setMode(false); });
          onlineBtn = makeLuciTab(_('Онлайн'), online, function() { setMode(true); url.focus(); });
          var typeRow = E('ul', { class: 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', style: 'margin:.4rem 0;' }, [localBtn, onlineBtn]);
          var field = function(label, input) { return E('div', { style: 'margin:.35rem 0;' }, [E('label', { style: 'display:block; opacity:.8; margin-bottom:.15rem;' }, label), input]); };
          urlField = field(_('Ссылка'), url);
          intervalField = field(_('Обновление'), interval.element);
          localStatus = E('div', { style: 'margin:.5rem 0; opacity:.8;' }, _('Без обновлений'));
          var edit = E('div', { class: 'mihomo-config-card-edit', style: 'margin-top:.8rem;' }, [
              E('div', { style: 'margin:.35rem 0; opacity:.8;' }, _('Тип конфигурации')),
              typeRow,
              field(_('Название'), name),
              urlField,
              intervalField,
              localStatus,
              E('div', { style: 'display:flex; gap:.5rem; margin-top:.6rem;' }, [
                  E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action', click: function() {
                      var newName = name.value.trim().replace(/\.ya?ml$/i, '');
                      if (!newName || newName === 'config') { ui.addNotification(null, E('p', newName === 'config' ? _('Имя config зарезервировано Mihomo') : _('Введите название')), 'error'); return; }
                      var iv = online ? interval.value() : '0';
                      if (iv === null) return;
                      var rename = newName !== profile.name ? callProfilesRename(profile.name, newName) : Promise.resolve({ ok: true });
                      rename.then(function(res) {
                          if (!self.showRoutingError(res)) return;
                          return callSetUrl('config', newName, online ? url.value.trim() : '', iv);
                       }).then(function(res) {
                           if (!res || !self.showRoutingError(res)) return;
                           if (newName !== profile.name) {
                               var order = (self.configsOrderArr || []).slice();
                               var index = order.indexOf(profile.name);
                               if (index === -1) order.push(newName);
                               else order[index] = newName;
                               self.configsOrderArr = order;
                               self.persistOrder('configs', order);
                           } else {
                               self.refreshProfiles();
                           }
                       }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                  }}, _('Сохранить')),
                  E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { edit.remove(); actions.style.display = 'flex'; if (head) head.style.display = ''; if (detailBox) detailBox.style.display = ''; } }, _('Закрыть'))
              ])
          ]);
          cardEl.insertBefore(edit, actions);
          setMode(online);
     },

     renderConfigsList: function(container) {
        L.dom.content(container, []);
        var self = this;
        var data = this.profilesData || {};
        var profiles = data.profiles || [];
        var active = data.active || '';
        if (this.configsOrderArr) {
            profiles.sort(function(a, b) {
                var ia = self.configsOrderArr.indexOf(a.name), ib = self.configsOrderArr.indexOf(b.name);
                if (ia === -1) ia = self.configsOrderArr.length;
                if (ib === -1) ib = self.configsOrderArr.length;
                return ia - ib;
            });
        }
        var grid = E('div', { class: 'mihomo-overview-cards' });
         var mkCard = function(id, title, detail, isOk, actions) {
             var detailEl = detail && detail.classList && detail.classList.contains('mihomo-overview-card-detail') ? detail : E('div', { class: 'mihomo-overview-card-detail' }, detail);
             var cardEl = E('div', { class: 'mihomo-overview-card ' + (isOk ? 'is-ok' : 'is-muted'), draggable: true }, [
                 E('div', { class: 'mihomo-overview-card-head' }, [
                     E('div', { class: 'mihomo-overview-card-title' }, title)
                 ]),
                 detailEl,
                 E('div', { class: 'mihomo-overview-card-actions' }, actions)
             ]);
             if (id) {
                 cardEl.setAttribute('data-config-name', id);
                 cardEl.addEventListener('dragstart', function(ev) {
                    self.configDragSource = id;
                    cardEl.classList.add('mihomo-overview-dragging');
                    try { ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', id); } catch (e) {}
                });
                cardEl.addEventListener('dragover', function(ev) { ev.preventDefault(); cardEl.classList.add('mihomo-overview-drag-over'); });
                cardEl.addEventListener('dragleave', function() { cardEl.classList.remove('mihomo-overview-drag-over'); });
                cardEl.addEventListener('drop', function(ev) {
                    ev.preventDefault();
                    cardEl.classList.remove('mihomo-overview-drag-over');
                    var source = self.configDragSource || (ev.dataTransfer && ev.dataTransfer.getData('text/plain'));
                    self.configDragSource = null;
                    if (!source || source === id) return;
                    var order = (self.configsOrderArr || []).slice();
                    var from = order.indexOf(source);
                    var to = order.indexOf(id);
                    if (from === -1 || to === -1) return;
                    order.splice(to, 0, order.splice(from, 1)[0]);
                    self.configsOrderArr = order;
                    self.renderConfigsList(container);
                    self.persistOrder('configs', order);
                });
                cardEl.addEventListener('dragend', function() { self.configDragSource = null; cardEl.classList.remove('mihomo-overview-dragging'); });
            }
            return cardEl;
        };

        profiles.forEach(function(p, idx) {
             var isActive = (p.name === active);
             var label = p.name === 'default' ? 'Default (default.yaml)' : p.name + '.yaml';
             var profPath = '/etc/mihomo/profiles/' + p.name + '.yaml';
             var detail = E('div', { class: 'mihomo-overview-card-detail' }, [E('div', {}, p.url || _('Локальная конфигурация'))]);
             detail.appendChild(E('div', {}, p.url ? (p.interval && p.interval !== '0' ? self.updateHoursLabel(p.interval) : _('Без обновлений')) : _('Без обновлений')));
             var actions = [
                 E('button', { 'class': 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { var card = ev.currentTarget; while (card && !card.classList.contains('mihomo-overview-card')) card = card.parentNode; if (card) self.openConfigCardEdit(card, p, profPath); } }, _('Изменить данные')),
                 E('button', { 'class': 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { self.toggleConfigEditor(profPath); } }, _('Открыть в редакторе'))
             ];
            if (!isActive) actions.push(E('button', { 'class': 'btn cbi-button-positive mihomo-overview-card-action', click: function() { self.applyProfile(p.name); } }, _('Применить')));
            if (p.url) actions.push(E('button', { 'class': 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { self.refreshSource('config', p.name); } }, _('Обновить')));
            if (!isActive) actions.push(E('button', { 'class': 'btn cbi-button-reset mihomo-overview-card-action', click: function() {
                if (confirm(_('Удалить %s?').format(p.name))) callProfilesDelete(p.name).then(function(res) {
                    if (self.showRoutingError(res)) {
                        var deletedPath = '/etc/mihomo/profiles/' + p.name + '.yaml';
                        if (currentConfigFile === deletedPath) currentConfigFile = MAIN_CONFIG;
                        if (currentFile === deletedPath) self.handleSelectFile(MAIN_CONFIG);
                        self.refreshProfiles();
                    }
                }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            }}, _('Удалить')));
            grid.appendChild(mkCard(p.name, label, detail, isActive, actions));
        });
        container.appendChild(grid);
    },

    renderRulesAdd: function(container) {
        L.dom.content(container, []);
        var self = this;
        var notifyRulesCreated = function() { ui.addNotification(null, E('p', _('Список правил создан. Для просмотра нажмите «Все списки».')), 'info'); };
        var inStyle = 'width:100%; max-width:26rem;';

        container.appendChild(E('h4', _('Локально')));
        var lName = E('input', { type: 'text', style: inStyle });
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Название'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [lName]));
        var lExt = E('select', { style: 'width:auto; min-width:8rem;' }, [E('option', { value: '.yaml' }, '.yaml'), E('option', { value: '.txt' }, '.txt')]);
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Формат списка'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [lExt]));
        var lPick = this.mkFilePicker('.yaml,.yml,.txt');
        
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [lPick.btn]));
        container.appendChild(E('div', { style: 'margin:.5rem 0;' }, [
            E('button', { 'class': 'btn cbi-button-positive', click: function() {
                var nm = lName.value.trim();
                var file = lPick.input.files && lPick.input.files[0];
                if (!nm && file) { nm = file.name.replace(/\.(yaml|yml|txt)$/i, ''); }
                if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                if (file) {
                    var reader = new FileReader();
                    reader.onload = function() {
                        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Создание...'))]);
                        callRulesImport(nm, '', reader.result, lExt.value, '').then(function(res) {
                            ui.hideModal();
                            if (self.showRoutingError(res)) { notifyRulesCreated(); self.refreshProfiles(); }
                        }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                    };
                    reader.readAsText(file);
                } else {
                    if (!validateFilename(nm)) { ui.addNotification(null, E('p', _('Некорректное имя')), 'error'); return; }
                    var fullPath = RULE_DIR + nm + lExt.value;
                    if (!validatePath(fullPath, RULE_DIR)) { ui.addNotification(null, E('p', _('Недопустимый путь')), 'error'); return; }
                    ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Создание...'))]);
                    fs.stat(fullPath).then(function() {
                        ui.hideModal(); ui.addNotification(null, E('p', _('Файл уже существует')), 'error');
                    }).catch(function() {
                        fs.write(fullPath, '').then(function() { return fs.list(RULE_DIR); }).then(function(files) {
                        cachedRuleFiles = (files || []);
                            ui.hideModal();
                            notifyRulesCreated();
                            self.renderFilesPanel(document.getElementById('mihomo-files-panel'));
                            self.handleSelectFile(fullPath);
                        }).catch(function(err) { ui.hideModal(); ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
                    });
                }
            }}, _('Создать'))
        ]));

        container.appendChild(E('h4', { style: 'margin-top:1rem;' }, _('Онлайн')));
        var oName = E('input', { type: 'text', style: inStyle });
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Название'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [oName]));
        var oExt = E('select', { style: 'width:auto; min-width:8rem;' }, [E('option', { value: '.yaml' }, '.yaml'), E('option', { value: '.txt' }, '.txt')]);
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Формат списка'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [oExt]));
        var oUrl = E('input', { type: 'text', placeholder: '', style: inStyle });
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Ссылка'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [oUrl]));
        var oInterval = this.mkIntervalEditor();
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [E('span', {}, _('Обновлять'))]));
        container.appendChild(E('div', { style: 'margin:.3rem 0;' }, [oInterval.element]));
         container.appendChild(E('div', { style: 'margin:.5rem 0;' }, [
             E('button', { 'class': 'btn cbi-button-positive', click: function() {
                 var nm = oName.value.trim();
                 if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                 var url = oUrl.value.trim();
                 if (!url) { ui.addNotification(null, E('p', _('Укажите ссылку')), 'error'); return; }
                 var interval = oInterval.value();
                 if (interval === null) return;
                 ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Импорт...'))]);
                 callRulesImport(nm, url, '', oExt.value, interval).then(function(res) {
                     ui.hideModal();
                     if (self.showRoutingError(res)) { notifyRulesCreated(); self.refreshProfiles(); }
                 }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
             }}, _('Импортировать'))
         ]));
         var ruleNodes = [];
         while (container.firstChild) ruleNodes.push(container.removeChild(container.firstChild));
         var ruleSections = [];
         var ruleTitles = [];
         var currentSection = null;
         ruleNodes.forEach(function(node) {
             if (node.tagName === 'H4') {
                 currentSection = E('div', { style: 'margin-top:1rem;' });
                 ruleSections.push(currentSection);
                 ruleTitles.push(node.textContent);
             } else if (currentSection) {
                 currentSection.appendChild(node);
             }
         });
         var ruleButtons = E('ul', { class: 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', style: 'margin:.5rem 0 1rem;' });
          ruleTitles.forEach(function(title, idx) {
              ruleButtons.appendChild(makeLuciTab(_(title), idx === 0, function() {
                  var isOpen = ruleSections[idx].style.display !== 'none';
                  ruleSections.forEach(function(section) { section.style.display = 'none'; });
                  Array.prototype.forEach.call(ruleButtons.children, function(tab) { tab.classList.add('cbi-tab-disabled'); });
                  if (!isOpen) {
                      ruleSections[idx].style.display = 'block';
                      ruleButtons.children[idx].classList.remove('cbi-tab-disabled');
                  }
              }));
          });
         container.appendChild(ruleButtons);
         ruleSections.forEach(function(section, idx) { section.style.display = idx === 0 ? 'block' : 'none'; container.appendChild(section); });
     },

      openRuleCardEdit: function(cardEl, file, meta, fullPath) {
          var self = this;
          var actions = cardEl.querySelector('.mihomo-overview-card-actions');
          if (!actions || cardEl.querySelector('.mihomo-config-card-edit')) return;
          actions.style.display = 'none';
          var head = cardEl.querySelector('.mihomo-overview-card-head');
          var detailBox = cardEl.querySelector('.mihomo-overview-card-detail');
          if (head) head.style.display = 'none';
          if (detailBox) detailBox.style.display = 'none';
          var ext = file.name.endsWith('.txt') ? '.txt' : '.yaml';
          var base = file.name.slice(0, -ext.length);
          var name = E('input', { type: 'text', value: base + ext, style: 'width:100%; box-sizing:border-box;' });
          var url = E('input', { type: 'text', value: meta.url || '', style: 'width:100%; box-sizing:border-box;', placeholder: _('Укажите ссылку') });
          var extSelect = E('select', { style: 'width:5rem;' }, [E('option', { value: '.yaml' }, '.yaml'), E('option', { value: '.txt' }, '.txt')]);
          extSelect.value = ext;
          var interval = this.mkIntervalEditor();
          var intervalSelect = interval.element.querySelector('select');
          var currentInterval = String(meta.interval || '0');
          if (currentInterval !== '0' && ['1', '3', '6', '12', '24'].indexOf(currentInterval) === -1) intervalSelect.appendChild(E('option', { value: currentInterval }, self.hoursPrefixLabel(currentInterval)));
          intervalSelect.value = currentInterval;
          var localBtn;
          var onlineBtn;
          var online = !!meta.url;
          var urlField;
          var intervalField;
          var localStatus;
          var setMode = function(isOnline) {
              online = isOnline;
              localBtn.classList.toggle('cbi-tab-disabled', online);
              onlineBtn.classList.toggle('cbi-tab-disabled', !online);
              urlField.style.display = online ? 'block' : 'none';
              intervalField.style.display = online ? 'block' : 'none';
              localStatus.style.display = online ? 'none' : 'block';
          };
          localBtn = makeLuciTab(_('Локально'), !online, function() { setMode(false); });
          onlineBtn = makeLuciTab(_('Онлайн'), online, function() { setMode(true); url.focus(); });
          var field = function(label, input) { return E('div', { style: 'margin:.35rem 0;' }, [E('label', { style: 'display:block; opacity:.8; margin-bottom:.15rem;' }, label), input]); };
          urlField = field(_('Ссылка'), url);
          intervalField = field(_('Обновление'), interval.element);
          localStatus = E('div', { style: 'margin:.5rem 0; opacity:.8;' }, _('Без обновлений'));
          var edit = E('div', { class: 'mihomo-config-card-edit', style: 'margin-top:.8rem;' }, [
              E('div', { style: 'margin:.35rem 0; opacity:.8;' }, _('Тип конфигурации')),
              E('ul', { class: 'cbi-tabmenu mihomo-settings-row mihomo-sub-row', style: 'margin:.4rem 0;' }, [localBtn, onlineBtn]),
              field(_('Название'), name),
              field(_('Формат'), extSelect),
              urlField,
              intervalField,
              localStatus,
              E('div', { style: 'display:flex; gap:.5rem; margin-top:.6rem;' }, [
                  E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action', click: function() {
                      var newBase = name.value.trim().replace(/\.(yaml|yml|txt)$/i, '');
                      if (!validateFilename(newBase)) { ui.addNotification(null, E('p', _('Некорректное имя')), 'error'); return; }
                      var targetName = newBase + extSelect.value;
                      var iv = online ? interval.value() : '0';
                      if (iv === null) return;
                      var rename = targetName !== file.name ? callRulesRename(file.name, newBase, extSelect.value) : Promise.resolve({ ok: true });
                      rename.then(function(res) {
                          if (!self.showRoutingError(res)) return;
                          return callSetUrl('rules', targetName, online ? url.value.trim() : '', iv);
                      }).then(function(res) {
                          if (res && self.showRoutingError(res)) self.refreshRuleFiles();
                      }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                  }}, _('Сохранить')),
                  E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { edit.remove(); actions.style.display = 'flex'; if (head) head.style.display = ''; if (detailBox) detailBox.style.display = ''; } }, _('Закрыть'))
              ])
          ]);
          cardEl.insertBefore(edit, actions);
          setMode(online);
      },

      renderRulesList: function(container) {
        L.dom.content(container, []);
        var self = this;
        var data = this.profilesData || {};
        var ruleMeta = data.rules || [];
        var metaMap = {};
        ruleMeta.forEach(function(r) { metaMap[r.name] = r; });

        var files = (cachedRuleFiles || []).filter(function(f) { return f.type === 'file'; });
        if (!this.rulesOrderArr || !this.rulesOrderArr.length) {
            this.rulesOrderArr = files.map(function(f) { return f.name; });
        }
        files.sort(function(a, b) {
            var ia = self.rulesOrderArr.indexOf(a.name), ib = self.rulesOrderArr.indexOf(b.name);
            if (ia === -1) ia = self.rulesOrderArr.length;
            if (ib === -1) ib = self.rulesOrderArr.length;
            return ia - ib;
        });
        var hasCurrentRule = currentRuleFile && files.some(function(file) { return RULE_DIR + file.name === currentRuleFile; });
         if (files.length && (this.selectFirstRuleOnOpen || !hasCurrentRule)) {
             currentRuleFile = RULE_DIR + files[0].name;
             this.selectFirstRuleOnOpen = false;
         } else if (!files.length) {
            currentRuleFile = '';
            this.selectFirstRuleOnOpen = false;
        }
        if (!files.length) {
            container.appendChild(E('p', { style: 'opacity:.75;' }, _('Списков правил пока нет.')));
         } else {
             var grid = E('div', { class: 'mihomo-overview-cards' });
              var mkCard = function(id, title, detail, actions) {
                  var detailEl = detail && detail.classList && detail.classList.contains('mihomo-overview-card-detail') ? detail : E('div', { class: 'mihomo-overview-card-detail' }, detail);
                  var cardEl = E('div', { class: 'mihomo-overview-card is-muted', draggable: true }, [
                      E('div', { class: 'mihomo-overview-card-head' }, [E('div', { class: 'mihomo-overview-card-title' }, title)]),
                      detailEl,
                      E('div', { class: 'mihomo-overview-card-actions' }, actions)
                  ]);
                 cardEl.addEventListener('dragstart', function(ev) {
                     self.configDragSource = id;
                     cardEl.classList.add('mihomo-overview-dragging');
                     try { ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', id); } catch (e) {}
                 });
                 cardEl.addEventListener('dragover', function(ev) { ev.preventDefault(); cardEl.classList.add('mihomo-overview-drag-over'); });
                 cardEl.addEventListener('dragleave', function() { cardEl.classList.remove('mihomo-overview-drag-over'); });
                 cardEl.addEventListener('drop', function(ev) {
                     ev.preventDefault();
                     cardEl.classList.remove('mihomo-overview-drag-over');
                     var source = self.configDragSource || (ev.dataTransfer && ev.dataTransfer.getData('text/plain'));
                     self.configDragSource = null;
                     if (!source || source === id) return;
                     var order = (self.rulesOrderArr || []).slice();
                     var from = order.indexOf(source), to = order.indexOf(id);
                     if (from === -1 || to === -1) return;
                     order.splice(to, 0, order.splice(from, 1)[0]);
                     self.rulesOrderArr = order;
                     self.renderRulesList(container);
                     self.persistOrder('rules', order);
                 });
                 cardEl.addEventListener('dragend', function() { self.configDragSource = null; cardEl.classList.remove('mihomo-overview-dragging'); });
                 return cardEl;
             };
             files.forEach(function(f) {
                 var fullPath = RULE_DIR + f.name;
                 if (!validatePath(fullPath, RULE_DIR)) return;
                 var meta = metaMap[f.name] || {};
                 var detail = E('div', { class: 'mihomo-overview-card-detail' }, [E('div', {}, meta.url || _('Локальный список правил'))]);
                 detail.appendChild(E('div', {}, meta.url ? (meta.interval && meta.interval !== '0' ? self.updateHoursLabel(meta.interval) : _('Без обновлений')) : _('Без обновлений')));
                 var actions = [
                     E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { var card = ev.currentTarget; while (card && !card.classList.contains('mihomo-overview-card')) card = card.parentNode; if (card) self.openRuleCardEdit(card, f, meta, fullPath); } }, _('Изменить данные')),
                     E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { self.toggleConfigEditor(fullPath); } }, _('Открыть в редакторе'))
                 ];
                 if (meta.url) actions.push(E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { self.refreshSource('rules', f.name); } }, _('Обновить')));
                 actions.push(E('button', { class: 'btn cbi-button-reset mihomo-overview-card-action', click: function() { if (confirm(_('Удалить %s?').format(f.name))) self.handleDeleteRule(fullPath, f.name); } }, _('Удалить')));
                 grid.appendChild(mkCard(f.name, f.name, detail, actions));
             });
             container.appendChild(grid);
         }
    },

    openEditPanel: function(type, name, url, interval, path) {
        if (!this.editPanel) return;
        var self = this;
        var panel = this.editPanel;
        while (panel.firstChild) panel.removeChild(panel.firstChild);

        var nameField;
        var ruleExtField;
        var ruleFieldStyle = 'width:100%; max-width:26rem;';
        if (type === 'config') {
            nameField = E('input', { type: 'text', value: name, style: 'min-width:14rem;' });
        } else {
            var currentExt = name.endsWith('.txt') ? '.txt' : '.yaml';
            var baseName = name.slice(0, -currentExt.length);
            nameField = E('input', { type: 'text', value: baseName, style: ruleFieldStyle });
            ruleExtField = E('select', { style: 'width:4rem;' }, [
                E('option', { value: '.yaml' }, '.yaml'),
                E('option', { value: '.txt' }, '.txt')
            ]);
            ruleExtField.value = currentExt;
        }
        var urlIn = E('input', { type: 'text', value: url || '', style: type === 'rules' ? ruleFieldStyle : 'min-width:20rem;' });
        var presets = [0, 1, 3, 6, 12, 24];
        var cur = interval || '';
        var isCustom = (cur !== '' && presets.indexOf(parseInt(cur, 10)) === -1);
        var iSel = E('select', { style: type === 'rules' ? ruleFieldStyle : 'min-width:8rem;' }, presets.map(function(h) {
            return E('option', { value: String(h) }, h === 0 ? _('никогда') : h + ' ' + _('ч'));
        }).concat([E('option', { value: 'custom' }, _('Выбрать время (в часах)'))]));
        iSel.value = isCustom ? 'custom' : cur;
         var iIn = E('input', { type: 'number', min: '1', max: '8760', style: 'width:4.5rem; display:' + (isCustom ? 'inline-block' : 'none') + ';' });
         iIn.value = isCustom ? cur : '';
        iSel.addEventListener('change', function() {
            iIn.style.display = iSel.value === 'custom' ? 'inline-block' : 'none';
            if (iSel.value === 'custom' && !iIn.value) iIn.value = '12';
        });

        var row = function(label, el) {
            var d = E('div', { style: 'margin:.3rem 0;' });
            d.appendChild(E('label', { style: 'display:block; opacity:.8; margin-bottom:.15rem;' }, label));
            d.appendChild(el);
            return d;
        };

        panel.appendChild(row(_('Название'), nameField));
        if (type === 'rules') panel.appendChild(row(_('Формат'), ruleExtField));
        panel.appendChild(row(_('Ссылка'), urlIn));
        panel.appendChild(row(_('Обновлять'), E('div', { style: 'display:flex; align-items:center; gap:.3rem;' }, [iSel, iIn])));

        panel.appendChild(E('div', { style: 'margin:.6rem 0 0; display:flex; gap:.5rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive', click: function() {
                var newName = name;
                if (type === 'config') {
                    newName = nameField.value.trim();
                    if (!newName) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                    if (newName === 'config') { ui.addNotification(null, E('p', _('Имя config зарезервировано Mihomo')), 'error'); return; }
                } else {
                    newName = nameField.value.trim().replace(/\.(yaml|yml|txt)$/i, '');
                    if (!validateFilename(newName)) { ui.addNotification(null, E('p', _('Некорректное имя')), 'error'); return; }
                }
                var targetName = type === 'rules' ? newName + ruleExtField.value : newName;
                var iv = iSel.value;
                if (iv === 'custom') {
                    var n = iIn.value.trim();
                    if (!n || parseInt(n, 10) < 1 || parseInt(n, 10) > 8760) {
                        ui.addNotification(null, E('p', _('Интервал от 1 до 8760 часов')), 'error');
                        return;
                    }
                    iv = String(parseInt(n, 10));
                }
                var step = function() {
                    callSetUrl(type, targetName, urlIn.value.trim(), iv).then(function(res) {
                        if (self.showRoutingError(res)) {
                            if (type === 'rules' && targetName !== name) {
                                currentRuleFile = RULE_DIR + targetName;
                                self.rulesOrderArr = (self.rulesOrderArr || []).map(function(item) { return item === name ? targetName : item; });
                                if (currentFile === RULE_DIR + name) self.handleSelectFile(RULE_DIR + targetName);
                            } else if (type === 'config' && targetName !== name) {
                                var oldConfigPath = '/etc/mihomo/profiles/' + name + '.yaml';
                                var newConfigPath = '/etc/mihomo/profiles/' + targetName + '.yaml';
                                if (currentConfigFile === oldConfigPath) currentConfigFile = newConfigPath;
                                if (currentFile === oldConfigPath) self.handleSelectFile(newConfigPath);
                            }
                            self.hideEditPanel();
                            if (type === 'rules') self.refreshRuleFiles();
                            else self.refreshProfiles();
                        }
                    }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                };
                if (type === 'config' && newName !== name) {
                    callProfilesRename(name, newName).then(function(res) {
                        if (self.showRoutingError(res)) step();
                    }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                } else if (type === 'rules' && targetName !== name) {
                    callRulesRename(name, newName, ruleExtField.value).then(function(res) {
                        if (self.showRoutingError(res)) step();
                    }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                } else {
                    step();
                }
            }}, _('Сохранить')),
            E('button', { 'class': 'btn cbi-button-neutral', click: function() { self.hideEditPanel(); } }, _('Закрыть'))
        ]));
        panel.style.display = 'block';
    },

    hideEditPanel: function() {
        if (this.editPanel) this.editPanel.style.display = 'none';
    },

    applyProfile: function(name) {
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Применение...'))]);
        callProfilesApply(name).then(function(res) {
            ui.hideModal();
            if (self.showRoutingError(res)) self.refreshProfiles();
        }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
    },

    refreshSource: function(type, name) {
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Обновление...'))]);
        callRefreshSource(type, name).then(function(res) {
            ui.hideModal();
            if (self.showRoutingError(res)) self.refreshProfiles();
        }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
    },

    refreshRuleFiles: function() {
        var self = this;
        fs.list(RULE_DIR).then(function(files) {
            cachedRuleFiles = (files || []);
            self.refreshProfiles();
        }).catch(function() { self.refreshProfiles(); });
    },

    handleDeleteRule: function(fullPath, name) {
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Удаление...'))]);
        callRulesDelete(name).then(function(res) {
            ui.hideModal();
            if (self.showRoutingError(res)) {
                if (currentRuleFile === fullPath) currentRuleFile = '';
                if (currentFile === fullPath) self.handleSelectFile(MAIN_CONFIG);
                self.refreshRuleFiles();
            }
        }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
    },

    mkProfileSelect: function(current) {
        var profiles = (this.profilesData && this.profilesData.profiles) || [];
        var opts = [E('option', { value: '' }, _('—'))].concat(profiles.map(function(p) {
            return E('option', { value: p.name }, p.name);
        }));
        var s = E('select', { style: 'min-width:10rem;' }, opts);
        s.value = current || '';
        return s;
    },

    mkScheduleDayBox: function(initial) {
        var dayOrder = [1, 2, 3, 4, 5, 6, 0];
        var dayNames = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
        var selected = {};
        if (initial && initial !== 'all') {
            String(initial).split(',').forEach(function(v) { selected[String(v).trim()] = true; });
        }
        var selectAll = !initial || initial === 'all';
        var dayChecks = [];
        var dayValues = [];
        var allDays = E('input', { type: 'checkbox', style: 'flex-shrink:0; margin:0;' });
        var dayBox = E('div', { class: 'mihomo-day-box', style: 'display:block;' });
        dayBox.appendChild(E('label', { style: 'display:flex; align-items:center; gap:.6rem; margin:.35rem 0;' }, [allDays, E('span', {}, _('Все дни'))]));
        dayOrder.forEach(function(day) {
            var check = E('input', { type: 'checkbox', style: 'flex-shrink:0; margin:0;' });
            check.checked = selectAll || !!selected[String(day)];
            dayChecks.push(check);
            dayValues.push(day);
            dayBox.appendChild(E('label', { style: 'display:flex; align-items:center; gap:.6rem; margin:.35rem 0;' }, [check, E('span', {}, _(dayNames[day]))]));
            check.addEventListener('change', function() { allDays.checked = false; });
        });
        allDays.checked = selectAll;
        allDays.addEventListener('change', function() {
            dayChecks.forEach(function(check) { check.checked = allDays.checked; });
        });
        var getDays = function() {
            if (allDays.checked) return 'all';
            var chosen = dayChecks.map(function(check, idx) { return check.checked ? String(dayValues[idx]) : ''; }).filter(function(value) { return value !== ''; });
            return chosen.length ? chosen.join(',') : 'all';
        };
        return { box: dayBox, getDays: getDays };
    },

    refreshSchedule: function() {
        var self = this;
        return Promise.all([callScheduleList(), callProfilesList()]).then(function(data) {
            var res = data[0] || {}, pres = data[1] || {};
            if (res.ok !== true) { self.showRoutingError(res || { ok: false, error: _('Не удалось получить расписание') }); return; }
            self.scheduleData = res;
            self.profilesData = pres;
            var to = res.timeOrder || [];
            if (to.length) {
                self.schedTimeOrderArr = to.slice();
            } else if (!self.schedTimeOrderArr || !self.schedTimeOrderArr.length) {
                self.schedTimeOrderArr = (res.time || []).map(function(t) { return t.name; });
            }
            var tro = res.triggerOrder || [];
            if (tro.length) {
                self.schedTriggerOrderArr = tro.slice();
            } else if (!self.schedTriggerOrderArr || !self.schedTriggerOrderArr.length) {
                self.schedTriggerOrderArr = (res.trigger || []).map(function(t) { return t.name; });
            }
            self.renderSchedulePanel();
        }).catch(function(err) { ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
    },

      renderScheduleCards: function(data) {
          var self = this;
          var grid = E('div', { class: 'mihomo-overview-cards' });
           var yamlName = function(value) { return value ? value + (value.indexOf('.yaml') === -1 ? '.yaml' : '') : ''; };
           var plural = function(value, one, few, many) { var n = Math.abs(value) % 100, n1 = n % 10; return value + ' ' + (n >= 11 && n <= 19 ? many : n1 === 1 ? one : n1 >= 2 && n1 <= 4 ? few : many); };
           var dayCount = function(value) { return value === 'all' || !value ? 7 : value.split(',').filter(function(day) { return day !== ''; }).length; };
           var linkCount = function(value) { return value ? value.trim().split(/\s+/).filter(function(url) { return url !== ''; }).length : 0; };
           var timeDetail = function(item) { return (item.start || '—') + ' — ' + (item.end || '—') + ', ' + plural(dayCount(item.days), _('день'), _('дня'), _('дней')); };
           var linksDetail = function(item) { return plural(linkCount(item.urls), _('ссылка'), _('ссылки'), _('ссылок')) + ', ' + (item.mode === 'direct' ? _('Напрямую') : _('Через Mihomo')); };
          var addCard = function(type, name, enabled, configuration, scheduleType, detail) {
              var toggleLabel = enabled ? _('Отключить') : _('Включить');
              var actions = [E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function(ev) { var card = ev.currentTarget; while (card && !card.classList.contains('mihomo-overview-card')) card = card.parentNode; if (card) self.openScheduleCardEdit(card, type, name); } }, _('Изменить данные')),
                  E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() {
                      var target = !enabled;
                      var calls = type === 'combined' ? [callScheduleSetEnabled('time', name, target), callScheduleSetEnabled('trigger', name, target)] : [callScheduleSetEnabled(type, name, target)];
                      Promise.all(calls).then(function(res) { var ok = true; res.forEach(function(r) { if (!r || r.ok !== true) ok = false; }); if (!ok) self.showRoutingError(res[0] || { ok: false }); else self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                  } }, toggleLabel),
                  E('button', { class: 'btn cbi-button-reset mihomo-overview-card-action', click: function() {
                      if (!confirm(_('Удалить %s?').format(name))) return;
                      var calls = type === 'combined' ? [callScheduleDelete('time', name), callScheduleDelete('trigger', name)] : [callScheduleDelete(type, name)];
                      Promise.all(calls).then(function(res) { var ok = true; res.forEach(function(r) { if (!r || r.ok !== true) ok = false; }); if (!ok) self.showRoutingError(res[0] || { ok: false }); else self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                  } }, _('Удалить'))];
              grid.appendChild(E('div', { class: 'mihomo-overview-card ' + (enabled ? 'is-ok' : 'is-muted') }, [
                  E('div', { class: 'mihomo-overview-card-head' }, E('div', { class: 'mihomo-overview-card-title' }, name)),
                  E('div', { class: 'mihomo-overview-card-detail' }, _('Конфигурация') + ' ' + (configuration || '—')),
                  E('div', { class: 'mihomo-overview-card-detail' }, scheduleType + ': ' + detail),
                  E('div', { class: 'mihomo-overview-card-actions' }, actions)
              ]));
          };
          var times = data.time || [];
          var triggers = data.trigger || [];
          var timeByName = {};
          times.forEach(function(item) { timeByName[item.name] = item; });
          var triggerByName = {};
          triggers.forEach(function(item) { triggerByName[item.name] = item; });
          var names = [];
          times.forEach(function(item) { if (names.indexOf(item.name) === -1) names.push(item.name); });
          triggers.forEach(function(item) { if (names.indexOf(item.name) === -1) names.push(item.name); });
          names.forEach(function(name) {
              var t = timeByName[name];
              var g = triggerByName[name];
              if (t && g) {
                  addCard('combined', name, !!(t.enabled || g.enabled), yamlName(t.profile || g.primary), _('По триггеру и времени'), timeDetail(t) + ', ' + linksDetail(g));
              } else if (t) {
                  addCard('time', name, !!t.enabled, yamlName(t.profile), _('По времени'), timeDetail(t));
              } else {
                  addCard('trigger', name, !!g.enabled, yamlName(g.primary), _('По триггеру'), linksDetail(g));
              }
          });
          return grid;
      },

     renderSchedulePanel: function() {
        var panel = this.schedulePanel;
        if (!panel) return;
        var self = this;
        while (panel.firstChild) panel.removeChild(panel.firstChild);
        var data = this.scheduleData || {};

          var defaultValue = data.default || '';


         var dayOrder = [1, 2, 3, 4, 5, 6, 0];
         var dayNames = ['Воскресенье', 'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'];
          var makeDayBox = function() {
              var dayChecks = [];
              var dayValues = [];
              var allDays = E('input', { type: 'checkbox', style: 'flex-shrink:0; margin:0;' });
              var dayBox = E('div', { class: 'mihomo-day-box', style: 'display:block;' });
              dayBox.appendChild(E('label', { style: 'display:flex; align-items:center; gap:.6rem; margin:.35rem 0;' }, [allDays, E('span', {}, _('Все дни'))]));
              dayOrder.forEach(function(day) {
                  var check = E('input', { type: 'checkbox', style: 'flex-shrink:0; margin:0;' });
                  check.checked = true;
                  dayChecks.push(check);
                  dayValues.push(day);
                  dayBox.appendChild(E('label', { style: 'display:flex; align-items:center; gap:.6rem; margin:.35rem 0;' }, [check, E('span', {}, _(dayNames[day]))]));
                  check.addEventListener('change', function() { allDays.checked = false; });
              });
             allDays.checked = true;
             allDays.addEventListener('change', function() {
                 dayChecks.forEach(function(check) { check.checked = allDays.checked; });
             });
             var getDays = function() {
                 if (allDays.checked) return 'all';
                 var selected = dayChecks.map(function(check, idx) { return check.checked ? String(dayValues[idx]) : ''; }).filter(function(value) { return value !== ''; });
                 return selected.length ? selected.join(',') : 'all';
             };
             return { box: dayBox, getDays: getDays };
         };

         panel.appendChild(E('h4', { style: 'margin-top:1rem;' }, _('По времени')));
         var tName = E('input', { type: 'text', placeholder: '', style: 'min-width:8rem;' });
         var tProf = this.mkProfileSelect('');
         var tStart = E('input', { type: 'time', style: 'min-width:7rem;' });
         var tEnd = E('input', { type: 'time', style: 'min-width:7rem;' });
         var tDays = makeDayBox();
         var dayBox = tDays.box;
          var getDays = tDays.getDays;
          panel.appendChild(E('div', { class: 'mihomo-route-add', style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem; margin:.4rem 0;' }, [
              E('span', {}, _('Название расписания')), tName,
              E('span', {}, _('Профиль во время расписания')), tProf,
              E('span', {}, _('Время начала')), tStart,
              E('span', {}, _('Время окончания')), tEnd,
              E('span', {}, _('Дни недели')), dayBox,
             E('button', { 'class': 'btn cbi-button-positive', click: function() {
                var nm = tName.value.trim();
                if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                if (!tProf.value) { ui.addNotification(null, E('p', _('Выберите профиль')), 'error'); return; }
                callScheduleSave('time', nm, true, tProf.value, tStart.value, tEnd.value, getDays()).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
             }}, _('Сохранить'))
         ]));

         var times = data.time || [];
        if (!this.schedTimeOrderArr || !this.schedTimeOrderArr.length) {
            this.schedTimeOrderArr = times.map(function(t) { return t.name; });
        }
        times.sort(function(a, b) {
            var ia = self.schedTimeOrderArr.indexOf(a.name), ib = self.schedTimeOrderArr.indexOf(b.name);
            if (ia === -1) ia = self.schedTimeOrderArr.length;
            if (ib === -1) ib = self.schedTimeOrderArr.length;
            return ia - ib;
        });
        if (times.length) {
            var t1 = E('table', { class: 'table mihomo-routing-table', style: 'width:100%; margin-top:.4rem;' }, [E('thead', {}, E('tr', {}, [E('th', { class: 'mihomo-grip' }, ''), E('th', {}, _('Название')), E('th', {}, _('Профиль')), E('th', {}, _('Время')), E('th', {}, _('Дни')), E('th', {}, _('Статус')), E('th', {}, _('Действие'))]))]);
            var tb = E('tbody');
            times.forEach(function(t, idx) {
                var enCb = E('input', { type: 'checkbox', click: function() { callScheduleSetEnabled('time', t.name, enCb.checked).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } });
                enCb.checked = !!t.enabled;
                var firstTd = E('td', { class: 'mihomo-grip' });
                var tr = E('tr', {}, [
                    firstTd,
                    E('td', {}, t.name),
                    E('td', {}, t.profile),
                    E('td', {}, (t.start || '—') + ' — ' + (t.end || '—')),
                    E('td', {}, t.days === 'all' ? _('Все дни') : t.days),
                    E('td', {}, enCb),
                    E('td', {}, E('div', { class: 'mihomo-route-actions' }, [
                        E('button', { 'class': 'btn cbi-button-neutral', click: function() { self.editTimeSchedule(t); } }, _('Редактировать')),
                        E('button', { 'class': 'btn cbi-button-reset', click: function() { if (confirm(_('Удалить %s?').format(t.name))) callScheduleDelete('time', t.name).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } }, _('Удалить'))
                    ]))
                ]);
                firstTd.appendChild(self.mkMoveGroup({
                    up: function() { self.moveRow(self.schedTimeOrderArr, idx, -1); self.renderSchedulePanel(); self.persistOrder('sched_time', self.schedTimeOrderArr); },
                    down: function() { self.moveRow(self.schedTimeOrderArr, idx, 1); self.renderSchedulePanel(); self.persistOrder('sched_time', self.schedTimeOrderArr); },
                    dragIndex: idx, arr: self.schedTimeOrderArr, row: tr,
                    onChange: function() { self.renderSchedulePanel(); self.persistOrder('sched_time', self.schedTimeOrderArr); }
                }));
                tb.appendChild(tr);
            });
            t1.appendChild(tb);
            panel.appendChild(t1);
        } else {
            panel.appendChild(E('p', { style: 'opacity:.75;' }, _('Правил пока нет.')));
        }

        panel.appendChild(E('h4', { style: 'margin-top:1rem;' }, _('По триггеру')));
          var gName = E('input', { type: 'text', placeholder: '', style: 'min-width:8rem;' });
          var gUrls = E('input', { type: 'text', placeholder: '', style: 'min-width:14rem;' });
          var gInt = E('input', { type: 'number', min: '1', value: '3', placeholder: '3' });
           var gThr = E('input', { type: 'number', min: '1', value: '1', placeholder: '1' });
           var gMode = makeScheduleCheckMode('direct');
         var gPrim = this.mkProfileSelect('');
        var gFall = this.mkProfileSelect('');
panel.appendChild(E('div', { class: 'mihomo-route-add', style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem; margin:.4rem 0;' }, [
              E('span', {}, _('Название расписания')), gName,
              E('span', {}, _('Ссылки для проверки (можно указать несколько через пробел)')), gUrls,
              E('span', {}, _('Активный профиль при успешной загрузке ссылок')), gPrim,
              E('span', {}, _('Активный профиль при отсутствии загрузки ссылок')), gFall,
              E('span', {}, _('Частота проверки в минутах')), gInt,
              E('span', {}, _('Частота проверки во время сбоев в минутах')), gThr,
              E('span', {}, _('Тип подключения')), gMode,
             E('button', { 'class': 'btn cbi-button-positive', click: function() {
                var nm = gName.value.trim();
                if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                if (!gUrls.value.trim()) { ui.addNotification(null, E('p', _('Укажите хотя бы один URL')), 'error'); return; }
                callScheduleSave('trigger', nm, true, '', '', '', '', '', '', gUrls.value.trim(), gInt.value, gFall.value, gPrim.value, gThr.value, '', gMode.value).then(function(res) { if (self.showRoutingError(res)) { ui.addNotification(null, E('p', _('Расписание создано')), 'info'); self.refreshSchedule(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
             }}, _('Сохранить'))
         ]));

         var triggers = data.trigger || [];
        if (!this.schedTriggerOrderArr || !this.schedTriggerOrderArr.length) {
            this.schedTriggerOrderArr = triggers.map(function(t) { return t.name; });
        }
        triggers.sort(function(a, b) {
            var ia = self.schedTriggerOrderArr.indexOf(a.name), ib = self.schedTriggerOrderArr.indexOf(b.name);
            if (ia === -1) ia = self.schedTriggerOrderArr.length;
            if (ib === -1) ib = self.schedTriggerOrderArr.length;
            return ia - ib;
        });
        if (triggers.length) {
            var t2 = E('table', { class: 'table mihomo-routing-table', style: 'width:100%; margin-top:.4rem;' }, [E('thead', {}, E('tr', {}, [E('th', { class: 'mihomo-grip' }, ''), E('th', {}, _('Название')), E('th', {}, _('Проверка')), E('th', {}, _('Интервал, мин')), E('th', {}, _('Фолбэк')), E('th', {}, _('Статус')), E('th', {}, _('Действие'))]))]);
            var tb2 = E('tbody');
            triggers.forEach(function(t, idx) {
                var enCb = E('input', { type: 'checkbox', click: function() { callScheduleSetEnabled('trigger', t.name, enCb.checked).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } });
                enCb.checked = !!t.enabled;
                var firstTd = E('td', { class: 'mihomo-grip' });
                var tr = E('tr', {}, [
                    firstTd,
                    E('td', {}, t.name),
                    E('td', { style: 'word-break:break-all;' }, t.urls),
                    E('td', {}, t.interval),
                    E('td', {}, t.fallback || '—'),
                    E('td', {}, enCb),
                    E('td', {}, E('div', { class: 'mihomo-route-actions' }, [
                        E('button', { 'class': 'btn cbi-button-neutral', click: function() { self.editTriggerSchedule(t); } }, _('Редактировать')),
                        E('button', { 'class': 'btn cbi-button-reset', click: function() { if (confirm(_('Удалить %s?').format(t.name))) callScheduleDelete('trigger', t.name).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } }, _('Удалить'))
                    ]))
                ]);
                firstTd.appendChild(self.mkMoveGroup({
                    up: function() { self.moveRow(self.schedTriggerOrderArr, idx, -1); self.renderSchedulePanel(); self.persistOrder('sched_trigger', self.schedTriggerOrderArr); },
                    down: function() { self.moveRow(self.schedTriggerOrderArr, idx, 1); self.renderSchedulePanel(); self.persistOrder('sched_trigger', self.schedTriggerOrderArr); },
                    dragIndex: idx, arr: self.schedTriggerOrderArr, row: tr,
                    onChange: function() { self.renderSchedulePanel(); self.persistOrder('sched_trigger', self.schedTriggerOrderArr); }
                }));
                tb2.appendChild(tr);
            });
            t2.appendChild(tb2);
            panel.appendChild(t2);
         } else {
             panel.appendChild(E('p', { style: 'opacity:.75;' }, _('Правил пока нет.')));
         }

         panel.appendChild(E('h4', { style: 'margin-top:1rem;' }, _('По времени и триггеру')));
         var cName = E('input', { type: 'text', placeholder: '', style: 'min-width:8rem;' });
         var cUrls = E('input', { type: 'text', placeholder: '', style: 'min-width:14rem;' });
         var cInt = E('input', { type: 'number', min: '1', value: '3', placeholder: '3' });
          var cThr = E('input', { type: 'number', min: '1', value: '1', placeholder: '1' });
          var cMode = makeScheduleCheckMode('direct');
          var cPrim = this.mkProfileSelect('');
         var cFall = this.mkProfileSelect('');
         var cStart = E('input', { type: 'time', style: 'min-width:7rem;' });
         var cEnd = E('input', { type: 'time', style: 'min-width:7rem;' });
         var cDays = makeDayBox();
         panel.appendChild(E('div', { class: 'mihomo-route-add', style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem; margin:.4rem 0;' }, [
             E('span', {}, _('Название расписания')), cName,
             E('span', {}, _('Ссылки для проверки (можно указать несколько через пробел)')), cUrls,
             E('span', {}, _('Активный профиль при успешной загрузке ссылок')), cPrim,
             E('span', {}, _('Активный профиль при отсутствии загрузки ссылок')), cFall,
             E('span', {}, _('Частота проверки в минутах')), cInt,
              E('span', {}, _('Частота проверки во время сбоев в минутах')), cThr,
              E('span', {}, _('Тип подключения')), cMode,
              E('span', {}, _('Время начала')), cStart,
             E('span', {}, _('Время окончания')), cEnd,
             E('span', {}, _('Дни недели')), cDays.box,
             E('button', { 'class': 'btn cbi-button-positive', click: function() {
                 var nm = cName.value.trim();
                 if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                 if (!cUrls.value.trim()) { ui.addNotification(null, E('p', _('Укажите хотя бы один URL')), 'error'); return; }
                 if (!cPrim.value) { ui.addNotification(null, E('p', _('Выберите профиль')), 'error'); return; }
                 var days = cDays.getDays();
                 callScheduleSave('trigger', nm, true, '', '', '', '', '', '', cUrls.value.trim(), cInt.value, cFall.value, cPrim.value, cThr.value, '', cMode.value).then(function(res) {
                     if (!res || res.ok !== true) { self.showRoutingError(res || { ok: false }); return; }
                     callScheduleSave('time', nm, true, cPrim.value, cStart.value, cEnd.value, days).then(function(res2) { if (self.showRoutingError(res2)) { ui.addNotification(null, E('p', _('Расписание создано')), 'info'); self.refreshSchedule(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                 }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
             }}, _('Сохранить'))
         ]));
         var scheduleNodes = [];
         while (panel.firstChild) scheduleNodes.push(panel.removeChild(panel.firstChild));
         var scheduleSections = [];
         var scheduleTitles = [];
         var schedulePrefix = [];
         var scheduleSection = null;
         scheduleNodes.forEach(function(node) {
             if (node.tagName === 'H4') {
                 scheduleSection = E('div', { style: 'margin-top:1rem;' });
                 scheduleSections.push(scheduleSection);
                 scheduleTitles.push(node.textContent);
             } else if (scheduleSection) {
                 scheduleSection.appendChild(node);
             } else {
                 schedulePrefix.push(node);
             }
         });
         schedulePrefix.forEach(function(node) { panel.appendChild(node); });
         var makeDefaultBlock = function() {
             var defSel = self.mkProfileSelect(defaultValue);
             return E('div', { class: 'mihomo-route-add', style: 'display:flex; flex-direction:column; align-items:flex-start; gap:.4rem; margin:.5rem 0;' }, [
                 E('span', {}, _('Профиль по умолчанию')), defSel,
                 E('button', { 'class': 'btn cbi-button-neutral', click: function() {
                     callScheduleDefault(defSel.value).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                 }}, _('Сохранить'))
             ]);
         };
         var scheduleButtons = E('div', { class: 'mihomo-seg', style: 'margin:.5rem 0 1rem;' });
         scheduleTitles.forEach(function(title, idx) {
             scheduleButtons.appendChild(E('button', { class: 'btn cbi-button-neutral' + (idx === 0 ? ' active' : ''), click: function() {
                 scheduleSections.forEach(function(section, sectionIdx) { section.style.display = sectionIdx === idx ? 'block' : 'none'; });
                 Array.prototype.forEach.call(scheduleButtons.children, function(button, buttonIdx) { button.classList.toggle('active', buttonIdx === idx); });
             } }, _(title)));
         });
          panel.appendChild(scheduleButtons);
          scheduleSections.forEach(function(section, idx) { section.insertBefore(makeDefaultBlock(), section.firstChild); section.style.display = idx === 0 ? 'block' : 'none'; panel.appendChild(section); });
          scheduleButtons.style.display = 'none';
           if (this.activeThird === 'list') {
               scheduleSections.forEach(function(section) { section.style.display = 'none'; });
               if (!(data.time || []).length && !(data.trigger || []).length) panel.appendChild(E('p', { style: 'opacity:.75;' }, _('Расписания пока нет.')));
               else panel.appendChild(this.renderScheduleCards(data));
           } else {
               var selectedSection = this.activeFourth === 'time' ? 0 : (this.activeFourth === 'trigger' ? 1 : (this.activeFourth === 'combined' ? 2 : null));
               scheduleSections.forEach(function(section, idx) {
                   section.style.display = idx === selectedSection ? 'block' : 'none';
                   if (idx === selectedSection) {
                       var tables = section.querySelectorAll('table');
                       for (var i = 0; i < tables.length; i++) tables[i].style.display = 'none';
                   }
               });
          }
      },

     editTimeSchedule: function(t) {
        var self = this;
        var name = E('input', { type: 'text', value: t.name, style: 'width:100%;' });
        var prof = this.mkProfileSelect(t.profile);
        var start = E('input', { type: 'time', value: t.start || '', style: 'width:100%;' });
        var end = E('input', { type: 'time', value: t.end || '', style: 'width:100%;' });
        var days = E('select', { style: 'width:100%;' }, [E('option', { value: 'all' }, _('Все дни'))].concat([0, 1, 2, 3, 4, 5, 6].map(function(d) {
            return E('option', { value: String(d) }, _('День %s').format(_(['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'][d])));
        })));
        days.value = (t.days && t.days !== 'all') ? t.days : 'all';
        ui.showModal(_('Редактировать расписание'), [
            E('div', {}, [
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Название')), name]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Профиль')), prof]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('С')) , start]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('По')) , end]),
                E('div', { style: 'display:flex; align-items:center;' }, [E('label', { style: 'min-width:8rem;' }, _('Дни')), days])
            ]),
            E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отмена')), ' ',
                E('button', { class: 'btn cbi-button-positive', click: function() {
                    var nm = name.value.trim();
                    if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                    if (!prof.value) { ui.addNotification(null, E('p', _('Выберите профиль')), 'error'); return; }
                    callScheduleSave('time', nm, !!t.enabled, prof.value, start.value, end.value, days.value, '', '', '', '', '', '', '', t.name).then(function(res) { if (self.showRoutingError(res)) { ui.hideModal(); self.refreshSchedule(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                }}, _('Сохранить'))
            ])
        ]);
    },

    editTriggerSchedule: function(t) {
        var self = this;
        var name = E('input', { type: 'text', value: t.name, style: 'width:100%;' });
        var urls = E('input', { type: 'text', value: t.urls || '', style: 'width:100%;' });
        var prim = this.mkProfileSelect(t.primary);
        var fall = this.mkProfileSelect(t.fallback);
        var int = E('input', { type: 'number', min: '1', value: t.interval || '5', style: 'width:100%;' });
        var thr = E('input', { type: 'number', min: '1', value: t.threshold || '2', style: 'width:100%;' });
         var mode = makeScheduleCheckMode(t.mode);
        ui.showModal(_('Редактировать расписание'), [
            E('div', {}, [
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Название')), name]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('URL-адреса')), urls]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Основной профиль')), prim]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Фолбэк')), fall]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Интервал, мин')), int]),
                 E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Порог сбоев')), thr]),
                 E('div', { style: 'display:flex; align-items:center;' }, [E('label', { style: 'min-width:8rem;' }, _('Тип подключения')), mode])
            ]),
            E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отмена')), ' ',
                E('button', { class: 'btn cbi-button-positive', click: function() {
                    var nm = name.value.trim();
                    if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                    if (!urls.value.trim()) { ui.addNotification(null, E('p', _('Укажите хотя бы один URL')), 'error'); return; }
                    callScheduleSave('trigger', nm, !!t.enabled, '', '', '', '', '', '', urls.value.trim(), int.value, fall.value, prim.value, thr.value, t.name, mode.value).then(function(res) { if (self.showRoutingError(res)) { ui.hideModal(); self.refreshSchedule(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                }}, _('Сохранить'))
            ])
        ]);
    },

    editCombinedSchedule: function(name) {
        var self = this;
        var data = this.scheduleData || {};
        var t = ((data.time || []).filter(function(x) { return x.name === name; })[0]) || { name: name };
        var g = ((data.trigger || []).filter(function(x) { return x.name === name; })[0]) || { name: name };
        var nameInput = E('input', { type: 'text', value: name, style: 'width:100%;' });
        var urls = E('input', { type: 'text', value: g.urls || '', style: 'width:100%;' });
        var prim = this.mkProfileSelect(t.profile || g.primary);
        var fall = this.mkProfileSelect(g.fallback);
        var int = E('input', { type: 'number', min: '1', value: g.interval || '3', style: 'width:100%;' });
         var thr = E('input', { type: 'number', min: '1', value: g.threshold || '1', style: 'width:100%;' });
         var mode = makeScheduleCheckMode(g.mode);
         var start = E('input', { type: 'time', value: t.start || '', style: 'width:100%;' });
        var end = E('input', { type: 'time', value: t.end || '', style: 'width:100%;' });
        var days = E('select', { style: 'width:100%;' }, [E('option', { value: 'all' }, _('Все дни'))].concat([0, 1, 2, 3, 4, 5, 6].map(function(d) {
            return E('option', { value: String(d) }, _('День %s').format(_(['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'][d])));
        })));
        days.value = (t.days && t.days !== 'all') ? t.days : 'all';
        ui.showModal(_('Редактировать расписание'), [
            E('div', {}, [
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Название')), nameInput]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('URL-адреса')), urls]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Основной профиль')), prim]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Фолбэк')), fall]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Интервал, мин')), int]),
                 E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Порог сбоев')), thr]),
                 E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('Тип подключения')), mode]),
                 E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('С')), start]),
                E('div', { style: 'display:flex; align-items:center; margin-bottom:.6rem;' }, [E('label', { style: 'min-width:8rem;' }, _('По')), end]),
                E('div', { style: 'display:flex; align-items:center;' }, [E('label', { style: 'min-width:8rem;' }, _('Дни')), days])
            ]),
            E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отмена')), ' ',
                E('button', { class: 'btn cbi-button-positive', click: function() {
                    var nm = nameInput.value.trim();
                    if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                    if (!urls.value.trim()) { ui.addNotification(null, E('p', _('Укажите хотя бы один URL')), 'error'); return; }
                    if (!prim.value) { ui.addNotification(null, E('p', _('Выберите профиль')), 'error'); return; }
                    callScheduleSave('trigger', nm, !!g.enabled, '', '', '', '', '', '', urls.value.trim(), int.value, fall.value, prim.value, thr.value, name, mode.value).then(function(res) {
                        if (!res || res.ok !== true) { self.showRoutingError(res || { ok: false }); return; }
                        callScheduleSave('time', nm, !!t.enabled, prim.value, start.value, end.value, days.value, '', '', '', '', '', '', '', name).then(function(res2) { if (self.showRoutingError(res2)) { ui.hideModal(); self.refreshSchedule(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                    }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                }}, _('Сохранить'))
            ])
        ]);
    },

    openScheduleCardEdit: function(cardEl, type, name) {
        var self = this;
        var actions = cardEl.querySelector('.mihomo-overview-card-actions');
        if (!actions || cardEl.querySelector('.mihomo-config-card-edit')) return;
        var data = this.scheduleData || {};
        var t = ((data.time || []).filter(function(x) { return x.name === name; })[0]) || { name: name };
        var g = ((data.trigger || []).filter(function(x) { return x.name === name; })[0]) || { name: name };
        actions.style.display = 'none';
        var head = cardEl.querySelector('.mihomo-overview-card-head');
        var details = cardEl.querySelectorAll('.mihomo-overview-card-detail');
        if (head) head.style.display = 'none';
        for (var di = 0; di < details.length; di++) details[di].style.display = 'none';
        var field = function(label, input) { return E('div', { style: 'margin:.35rem 0;' }, [E('label', { style: 'display:block; opacity:.8; margin-bottom:.15rem;' }, label), input]); };
        var rows = [];
        var onSave = null;
        if (type === 'time') {
            var nameInput = E('input', { type: 'text', value: t.name, style: 'width:100%; box-sizing:border-box;' });
            var prof = this.mkProfileSelect(t.profile);
            prof.style.width = '100%';
            prof.style.boxSizing = 'border-box';
            var start = E('input', { type: 'time', value: t.start || '', style: 'width:100%; box-sizing:border-box;' });
            var end = E('input', { type: 'time', value: t.end || '', style: 'width:100%; box-sizing:border-box;' });
            var days = this.mkScheduleDayBox(t.days || 'all');
            rows.push(field(_('Название расписания'), nameInput));
            rows.push(field(_('Профиль во время расписания'), prof));
            rows.push(field(_('Время начала'), start));
            rows.push(field(_('Время окончания'), end));
            rows.push(field(_('Дни недели'), days.box));
            onSave = function() {
                var nm = nameInput.value.trim();
                if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                if (!prof.value) { ui.addNotification(null, E('p', _('Выберите профиль')), 'error'); return; }
                callScheduleSave('time', nm, !!t.enabled, prof.value, start.value, end.value, days.getDays(), '', '', '', '', '', '', '', t.name).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            };
        } else if (type === 'trigger') {
            var tName = E('input', { type: 'text', value: g.name, style: 'width:100%; box-sizing:border-box;' });
            var urls = E('input', { type: 'text', value: g.urls || '', style: 'width:100%; box-sizing:border-box;' });
            var prim = this.mkProfileSelect(g.primary);
            prim.style.width = '100%';
            prim.style.boxSizing = 'border-box';
            var fall = this.mkProfileSelect(g.fallback);
            fall.style.width = '100%';
            fall.style.boxSizing = 'border-box';
            var int = E('input', { type: 'number', min: '1', value: g.interval || '3', style: 'width:100%; box-sizing:border-box;' });
             var thr = E('input', { type: 'number', min: '1', value: g.threshold || '1', style: 'width:100%; box-sizing:border-box;' });
             var mode = makeScheduleCheckMode(g.mode);
             rows.push(field(_('Название расписания'), tName));
            rows.push(field(_('Ссылки для проверки (можно указать несколько через пробел)'), urls));
            rows.push(field(_('Активный профиль при успешной загрузке ссылок'), prim));
            rows.push(field(_('Активный профиль при отсутствии загрузки ссылок'), fall));
            rows.push(field(_('Частота проверки в минутах'), int));
             rows.push(field(_('Частота проверки во время сбоев в минутах'), thr));
             rows.push(field(_('Тип подключения'), mode));
             onSave = function() {
                 var nm = tName.value.trim();
                if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                if (!urls.value.trim()) { ui.addNotification(null, E('p', _('Укажите хотя бы один URL')), 'error'); return; }
                callScheduleSave('trigger', nm, !!g.enabled, '', '', '', '', '', '', urls.value.trim(), int.value, fall.value, prim.value, thr.value, g.name, mode.value).then(function(res) { if (self.showRoutingError(res)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            };
        } else {
            var cName = E('input', { type: 'text', value: name, style: 'width:100%; box-sizing:border-box;' });
            var cUrls = E('input', { type: 'text', value: g.urls || '', style: 'width:100%; box-sizing:border-box;' });
            var cPrim = this.mkProfileSelect(t.profile || g.primary);
            cPrim.style.width = '100%';
            cPrim.style.boxSizing = 'border-box';
            var cFall = this.mkProfileSelect(g.fallback);
            cFall.style.width = '100%';
            cFall.style.boxSizing = 'border-box';
            var cInt = E('input', { type: 'number', min: '1', value: g.interval || '3', style: 'width:100%; box-sizing:border-box;' });
            var cThr = E('input', { type: 'number', min: '1', value: g.threshold || '1', style: 'width:100%; box-sizing:border-box;' });
             var cMode = makeScheduleCheckMode(g.mode);
            var cStart = E('input', { type: 'time', value: t.start || '', style: 'width:100%; box-sizing:border-box;' });
            var cEnd = E('input', { type: 'time', value: t.end || '', style: 'width:100%; box-sizing:border-box;' });
            var cDays = this.mkScheduleDayBox(t.days || 'all');
            rows.push(field(_('Название расписания'), cName));
            rows.push(field(_('Ссылки для проверки (можно указать несколько через пробел)'), cUrls));
            rows.push(field(_('Активный профиль при успешной загрузке ссылок'), cPrim));
            rows.push(field(_('Активный профиль при отсутствии загрузки ссылок'), cFall));
            rows.push(field(_('Частота проверки в минутах'), cInt));
             rows.push(field(_('Частота проверки во время сбоев в минутах'), cThr));
             rows.push(field(_('Тип подключения'), cMode));
             rows.push(field(_('Время начала'), cStart));
            rows.push(field(_('Время окончания'), cEnd));
            rows.push(field(_('Дни недели'), cDays.box));
            onSave = function() {
                var nm = cName.value.trim();
                if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                if (!cUrls.value.trim()) { ui.addNotification(null, E('p', _('Укажите хотя бы один URL')), 'error'); return; }
                if (!cPrim.value) { ui.addNotification(null, E('p', _('Выберите профиль')), 'error'); return; }
                callScheduleSave('trigger', nm, !!g.enabled, '', '', '', '', '', '', cUrls.value.trim(), cInt.value, cFall.value, cPrim.value, cThr.value, name, cMode.value).then(function(res) {
                    if (!res || res.ok !== true) { self.showRoutingError(res || { ok: false }); return; }
                    callScheduleSave('time', nm, !!t.enabled, cPrim.value, cStart.value, cEnd.value, cDays.getDays(), '', '', '', '', '', '', '', name).then(function(res2) { if (self.showRoutingError(res2)) self.refreshSchedule(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            };
        }
        var edit = E('div', { class: 'mihomo-config-card-edit', style: 'margin-top:.8rem;' }, rows.concat([E('div', { style: 'display:flex; gap:.5rem; margin-top:.6rem;' }, [
            E('button', { class: 'btn cbi-button-positive mihomo-overview-card-action', click: onSave }, _('Сохранить')),
            E('button', { class: 'btn cbi-button-neutral mihomo-overview-card-action', click: function() { edit.remove(); actions.style.display = 'flex'; if (head) head.style.display = ''; for (var i = 0; i < details.length; i++) details[i].style.display = ''; } }, _('Закрыть'))
        ])]));
        cardEl.insertBefore(edit, actions);
    },

    handleSelectFile: function(path) {
         editorRequested = true;
        if (!validatePath(path, '/etc/mihomo/')) { ui.addNotification(null, E('p', _('Недопустимый путь')), 'error'); return; }
        if (path === currentFile) { this.updateVisibility(path); return; }
        var self = this;
        var rememberFile = function() {
            if (path === MAIN_CONFIG || path.indexOf('/etc/mihomo/profiles/') === 0) {
                currentConfigFile = path;
            } else if (path.indexOf(RULE_DIR) === 0) {
                currentRuleFile = path;
            }
        };
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Загрузка...'))]);
        fs.read(path).then(function(content) {
            currentFile = path;
            rememberFile();
            if (editor) {
                editor.setValue(content || '', -1);
                editor.session.setMode(path.endsWith('.txt') ? "ace/mode/text" : "ace/mode/yaml");
            }
            self.renderToolbar(document.getElementById('mihomo-toolbar'), path);
            self.updateVisibility(path);
            self.renderFilesPanel(document.getElementById('mihomo-files-panel'));
            ui.hideModal();
        }).catch(function(err) {
            if (err && err.message === 'Данные не получены') {
                currentFile = path;
                rememberFile();
                if (editor) { editor.setValue('', -1); editor.session.setMode(path.endsWith('.txt') ? "ace/mode/text" : "ace/mode/yaml"); }
                self.renderToolbar(document.getElementById('mihomo-toolbar'), path);
                self.updateVisibility(path);
                self.renderFilesPanel(document.getElementById('mihomo-files-panel'));
            } else {
                ui.addNotification(null, E('p', _('Ошибка: ') + (err.message || 'Error')), 'error');
            }
            ui.hideModal();
        });
    },
    
    handleCreateFile: function() {
        var self = this;
        var nameInput = E('input', { 'type': 'text', 'style': 'width: 100%;', 'placeholder': 'my-rules' });
        var typeSelect = E('select', { 'style': 'width: 100%;' }, [
            E('option', { 'value': '.yaml' }, _('Набор правил (.yaml)')),
            E('option', { 'value': '.txt' }, _('Простой список (.txt)'))
        ]);
        var footer = E('div', { 'class': 'right', 'style': 'margin-top: 1.5rem;' }, [
            E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Отмена')), ' ',
            E('button', { 'class': 'btn cbi-button-positive', 'click': function() {
                var filename = nameInput.value.trim();
                if (!filename || !validateFilename(filename)) { ui.addNotification(null, E('p', _('Некорректное имя')), 'error'); return; }
                var fullPath = RULE_DIR + filename + typeSelect.value;
                if (!validatePath(fullPath, RULE_DIR)) { ui.addNotification(null, E('p', _('Недопустимый путь')), 'error'); return; }
                ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Создание...'))]);
                fs.stat(fullPath).then(function() {
                    ui.hideModal(); ui.addNotification(null, E('p', _('Файл уже существует')), 'error');
                }).catch(function() {
                    fs.write(fullPath, '').then(function() { return fs.list(RULE_DIR); }).then(function(files) {
            cachedRuleFiles = (files || []);
                        self.renderFilesPanel(document.getElementById('mihomo-files-panel'));
                        self.handleSelectFile(fullPath);
                    }).catch(function(err) { ui.hideModal(); ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
                });
            }}, _('Создать'))
        ]);
        ui.showModal(_('Новый файл правил'), [
            E('div', {}, [
                E('div', { 'style': 'display: flex; align-items: center; margin-bottom: 0.8rem;' }, [ E('label', { 'style': 'min-width: 10rem; margin-right: 0.8rem;' }, _('Имя файла:')), nameInput ]),
                E('div', { 'style': 'display: flex; align-items: center;' }, [ E('label', { 'style': 'min-width: 10rem; margin-right: 0.8rem;' }, _('Тип файла:')), typeSelect ])
            ]), footer
        ]);
        nameInput.focus();
    },

    handleSaveAndApply: function(wasRunning) {
        if (this.isProcessing) return Promise.reject(new Error('Busy'));
        if (!editor) return;
        this.isProcessing = true;
        var self = this;
        var content = editor.getValue();
        var configPath = currentFile;
        var profilePrefix = '/etc/mihomo/profiles/';
        var activeProfile = self.profilesData && (self.profilesData.active || self.profilesData.activeProfile);
        var activeProfilePath = activeProfile ? profilePrefix + activeProfile + '.yaml' : null;
        var isMihomoConfig = configPath === MAIN_CONFIG || configPath.indexOf(profilePrefix) === 0;
        var targetPaths = isMihomoConfig ? [MAIN_CONFIG] : [configPath];
        if (isMihomoConfig && activeProfilePath && targetPaths.indexOf(activeProfilePath) < 0) targetPaths.push(activeProfilePath);
        var prepared = {};
        var prepare = function(path) {
            if (path === configPath) return Promise.resolve(content);
            return fs.read(path).catch(function() { return ''; });
        };
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Сохранение...'))]);
        Promise.all(targetPaths.map(function(path) {
            return prepare(path).then(function(value) {
                prepared[path] = isMihomoConfig ? applyMihomoDefaults(value, self.dashboardPanel) : value;
            });
        })).then(function() {
            if (isMihomoConfig) {
                content = prepared[configPath];
                editor.setValue(content, -1);
                if (configPath === MAIN_CONFIG) mainConfigContent = content;
            }
            return targetPaths.reduce(function(promise, path) {
                return promise.then(function() { return fs.write(path, prepared[path]); }).then(function() { return normalizeEditorConfig(path); });
            }, Promise.resolve());
        }).then(function() {
            if (isMihomoConfig && activeProfilePath) {
                var profileName = activeProfilePath.slice(profilePrefix.length).replace(/\.ya?ml$/, '');
                return callProfilesApply(profileName).then(function(res) {
                    if (!res || !res.ok) throw new Error((res && res.error) || _('Не удалось применить профиль'));
                });
            }
        }).then(function() {
            if (isMihomoConfig) {
                return fs.exec('/usr/bin/mihomo', ['-d', '/etc/mihomo', '-t', MAIN_CONFIG]).then(function(res) {
                    if (res.code !== 0) throw new Error((res.stdout || '') + (res.stderr || ''));
                    if (wasRunning) return fs.exec('/etc/init.d/mihomo', ['restart']);
                });
            }
        }).then(function() {
            ui.hideModal();
            if (configPath === MAIN_CONFIG) setTimeout(function() { window.location.reload(); }, RELOAD_DELAY);
        }).catch(function(err) { self.showOutput(err.message, true); ui.hideModal(); }).finally(function() { self.isProcessing = false; });
    },
    
    handleCheck: function() {
        if (!editor || this.isChecking) return;
        var self = this;
        this.isChecking = true;
        var label = _('Проверить конфигурацию');
        var busy = _('Проверка...');
        var checkBtns = [document.getElementById('check-button'), document.getElementById('profile-check-button')].filter(function(b) { return !!b; });
        checkBtns.forEach(function(b) { b.disabled = true; b.textContent = busy; });
        var done = function() {
            self.isChecking = false;
            checkBtns.forEach(function(b) { b.disabled = false; b.textContent = label; });
        };
        var configPath = currentFile;
        fs.write(configPath, editor.getValue())
            .then(function() { return normalizeEditorConfig(configPath); })
            .then(function() { return fs.exec('/usr/bin/mihomo', ['-d', '/etc/mihomo', '-t', configPath]); })
            .then(function(res) { self.showOutput((res.stdout || '') + (res.stderr || ''), res.code !== 0); done(); })
            .catch(function(e) { self.showOutput(e.message, true); done(); });
    },
    
    showOutput: function(text, isError) {
        var box = document.getElementById('output-box');
        var out = document.getElementById('output-text');
        if (box && out) {
            out.textContent = text ? text.trim() : _('(Пусто)');
            out.style.color = isError ? '#f92672' : 'var(--text-output)';
            box.style.display = 'block';
            box.scrollIntoView({ behavior: 'smooth', block: 'end' });
        }
    },
    
    compareMagiVersions: function(left, right) {
        var base = function(v) { return String(v || '').replace(/^v/i, '').replace(/[-_]r\d+$/i, '').replace(/-\d+$/, ''); };
        var parts = function(v) { return (base(v).match(/[0-9]+/g) || []).map(function(n) { return parseInt(n, 10); }); };
        var a = parts(left), b = parts(right);
        var len = Math.max(a.length, b.length);
        for (var i = 0; i < len; i++) {
            var av = a[i] || 0, bv = b[i] || 0;
            if (av !== bv) return av > bv ? 1 : -1;
        }
        return 0;
    },

    magitrickleKillStale: function() {
        return "pids=$(pidof magitrickled 2>/dev/null); if [ -n \"$pids\" ]; then kill $pids 2>/dev/null; sleep 1; pids=$(pidof magitrickled 2>/dev/null); [ -n \"$pids\" ] && kill -9 $pids 2>/dev/null; fi; true";
    },

    magitrickleService: function(action) {
        return "[ -x /etc/init.d/magitrickle ] && /etc/init.d/magitrickle " + action + " >/dev/null 2>&1; " +
            "[ -x /opt/etc/init.d/S99magitrickle ] && /opt/etc/init.d/S99magitrickle " + action + " >/dev/null 2>&1; " +
            "command -v service >/dev/null 2>&1 && service magitrickle " + action + " >/dev/null 2>&1; true";
    },

    magitrickleRemoveCommand: function() {
        return "[ -f /etc/magitrickle/state/config.yaml ] && cp -f /etc/magitrickle/state/config.yaml /tmp/magitrickle_config_backup.yaml 2>/dev/null; " +
            "if command -v apk >/dev/null 2>&1; then " +
                "apk del magitrickle_mod magitrickle >/dev/null 2>&1 || true; " +
                "if apk list -I 2>/dev/null | grep -q '^magitrickle[.-]'; then apk del --force-broken-world magitrickle >/dev/null 2>&1 || true; fi; " +
                "apk list -I 2>/dev/null | grep -q '^magitrickle[.-]' && { echo '[magitrickle] не удалось удалить пакет'; exit 1; }; " +
            "else " +
                "opkg remove magitrickle_mod >/dev/null 2>&1 || true; " +
                "opkg remove magitrickle --force-depends >/dev/null 2>&1 || true; " +
                "opkg list-installed 2>/dev/null | grep -q '^magitrickle ' && { echo '[magitrickle] не удалось удалить пакет'; exit 1; }; " +
            "fi; " +
            "rm -f /etc/init.d/magitrickle /opt/etc/init.d/S99magitrickle; true";
    },

    magitrickleRestoreCommand: function() {
        return "[ -f /tmp/magitrickle_config_backup.yaml ] && { [ -f /etc/magitrickle/state/config.yaml ] || { mkdir -p /etc/magitrickle/state; cp -f /tmp/magitrickle_config_backup.yaml /etc/magitrickle/state/config.yaml; }; }; true";
    },

    magitrickleInstallCommand: function(variant) {
        if (variant === 'mod') {
            return "tmp=/tmp/magitrickle-mod.sh; if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 10 --max-time 300 https://raw.githubusercontent.com/badigit/MagiTrickle_mod_badigit/mod_badigit/scripts/install.sh -o $tmp; else wget -qO $tmp -T 300 https://raw.githubusercontent.com/badigit/MagiTrickle_mod_badigit/mod_badigit/scripts/install.sh; fi || { echo '[magitrickle] не удалось скачать установщик Mod'; exit 1; }; sh $tmp || exit 1";
        }
        return "tmp=/tmp/magitrickle-add-repo.sh; if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 10 --max-time 60 http://bin.magitrickle.dev/packages/add_repo.sh -o $tmp; else wget -qO $tmp -T 60 http://bin.magitrickle.dev/packages/add_repo.sh; fi || { echo '[magitrickle] не удалось скачать add_repo.sh'; exit 1; }; sh $tmp >/dev/null 2>&1 || { echo '[magitrickle] add_repo.sh завершился с ошибкой'; exit 1; }; " +
            "if command -v apk >/dev/null 2>&1; then apk update >/dev/null 2>&1; apk add magitrickle || exit 1; else opkg update >/dev/null 2>&1; opkg install magitrickle || exit 1; fi";
    },

    magitrickleVerifyInstall: function() {
        return "if command -v apk >/dev/null 2>&1; then apk list -I 2>/dev/null | grep -q '^magitrickle[.-]' || { echo '[magitrickle] пакет не установлен'; exit 1; }; else opkg list-installed 2>/dev/null | grep -q '^magitrickle ' || { echo '[magitrickle] пакет не установлен'; exit 1; }; fi; true";
    },

    magitrickleVersionFinalize: function(variant) {
        var tagCmd = "if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 10 --max-time 30 https://api.github.com/repos/badigit/MagiTrickle_mod_badigit/releases/latest 2>/dev/null | grep -m1 '\"tag_name\"' | sed 's/.*\"tag_name\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/'; else wget -qO- -T 30 https://api.github.com/repos/badigit/MagiTrickle_mod_badigit/releases/latest 2>/dev/null | grep -m1 '\"tag_name\"' | sed 's/.*\"tag_name\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/'; fi";
        var pkgCmd = "if command -v apk >/dev/null 2>&1; then apk info -v magitrickle 2>/dev/null | head -1 | sed -n 's/^magitrickle-//p' | cut -d' ' -f1 | tr -d ' \\r\\n'; else opkg list-installed 2>/dev/null | grep '^magitrickle ' | awk '{print $3}' | head -1 | tr -d ' \\r\\n'; fi";
        var resolve = variant === 'mod' ? "$(" + tagCmd + ")" : "$(" + pkgCmd + ")";
return "mkdir -p /etc/mixomo/versions; prev_variant=$(sed -n '1p' /etc/mixomo/versions/magitrickle 2>/dev/null | tr -d ' \\r\\n'); prev=$(sed -n '2p' /etc/mixomo/versions/magitrickle 2>/dev/null | tr -d ' \\r\\n'); " +
             "ver=" + resolve + "; ver=$(printf '%s' \"$ver\" | tr -d ' \\r\\n' | sed 's/[-_]r[0-9]*$//; s/-[0-9][0-9]*$//'); " +
             "[ -z \"$ver\" ] && [ \"$prev_variant\" = '" + variant + "' ] && ver=\"$prev\"; " +
             "printf '%s\\n%s\\n' '" + variant + "' \"$ver\" > /etc/mixomo/versions/magitrickle";
    },

    magitrickleInstallSteps: function(variant) {
        return [
            this.magitrickleService('stop'),
            this.magitrickleRemoveCommand(),
            this.magitrickleKillStale(),
            this.magitrickleInstallCommand(variant),
            this.magitrickleVerifyInstall(),
            this.magitrickleRestoreCommand(),
            this.magitrickleKillStale(),
            this.magitrickleService('enable'),
            this.magitrickleService('restart'),
            this.magitrickleVersionFinalize(variant)
        ];
    },

    runMagitrickleSteps: function(steps) {
        var marker = '/tmp/mixomo-magitrickle-task.rc';
        var log = '/tmp/mixomo-magitrickle-task.log';
        var chain = steps.map(function(shell, index) {
            return '( ' + shell + ' ) || { echo "[magitrickle] шаг ' + (index + 1) + ' завершился с ошибкой"; exit 1; }';
        }).join(' && ');
        var readMarker = function() {
            return fs.exec('/bin/sh', ['-c', 'cat ' + marker + ' 2>/dev/null']).then(function(res) {
                return (res && res.stdout) || '';
            }).catch(function() { return ''; });
        };
        var readLogTail = function() {
            return fs.exec('/bin/sh', ['-c', 'tail -20 ' + log + ' 2>/dev/null']).then(function(res) {
                return (res && res.stdout) || '';
            }).catch(function() { return ''; });
        };
        return fs.exec('/bin/sh', ['-c', 'rm -f ' + marker + ' ' + log + '; ( ( ' + chain + ' ) > ' + log + ' 2>&1; printf \'%s\' "$?" > ' + marker + ' ) >/dev/null 2>&1 < /dev/null &']).then(function() {
            var started = Date.now();
            var wait = function() {
                if (Date.now() - started > 600000) throw new Error(_('Превышено время ожидания операции MagiTrickle'));
                return readMarker().then(function(result) {
                    if (!String(result || '').trim()) {
                        return new Promise(function(resolve) { setTimeout(function() { resolve(wait()); }, 1000); });
                    }
                    if (String(result).trim() !== '0') {
                        return readLogTail().then(function(out) {
                            var tail = String(out || '').split('\n').filter(function(l) { return String(l || '').trim(); }).slice(-4).join('\n').trim();
                            throw new Error(tail || _('Не удалось выполнить операцию MagiTrickle'));
                        });
                    }
                });
            };
            return wait();
        });
    },

    setMixomoButtonIdle: function() {
        var button = this.mixomoUpdateButton;
        if (!button) return;
        var self = this;
        button.disabled = false;
        button.className = 'btn cbi-button-neutral';
        button.textContent = _('Проверить обновление');
        button.onclick = function(ev) { ev.stopPropagation(); self.checkMixomoUpdates(true); };
    },

    getMixomoState: function() {
        return fs.read('/etc/mixomo/versions/mixomo').then(function(state) {
            var lines = String(state || '').split(/\r?\n/);
            return { version: (lines[0] || '').trim(), sha: (lines[1] || '').trim() };
        }).catch(function() { return { version: _('Неизвестно'), sha: '' }; });
    },

    setMixomoTitle: function() {
        if (!this.mixomoTitleVersion) return;
        var version = this.mixomoVersion && this.mixomoVersion.version;
        this.mixomoTitleVersion.textContent = version ? ' ' + version : '';
    },

    mixomoManifestUrl: function() {
        return this.mixomoChannel === 'test'
            ? 'https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/manifest.test'
            : 'https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/v0.3.3/manifest.stable';
    },

    mixomoInstallerUrl: function() {
        return this.mixomoChannel === 'test'
            ? 'https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/test-install.sh'
            : 'https://raw.githubusercontent.com/Internet-Helper/mixomo-openwrt/main/install.sh';
    },

    checkMixomoUpdates: function(isManual) {
        var self = this;
        var button = this.mixomoUpdateButton;
        if (!button) return;
        if (isManual) {
            button.disabled = true;
            button.textContent = _('Проверка обновлений...');
        }
        var manifest = this.mixomoManifestUrl();
        var cmd = 'wget -qO- -T 30 "' + manifest + '" 2>/dev/null | grep -E "^(MIXOMO_VERSION|MIXOMO_BUNDLE_SHA256)="';
        fs.exec('/bin/sh', ['-c', cmd]).then(function(res) {
            var output = (res && res.stdout) || '';
            if (!output) throw new Error(_('Не удалось получить актуальную версию Mixomo'));
            var versionMatch = output.match(/^MIXOMO_VERSION=([^\r\n]+)/m);
            var shaMatch = output.match(/^MIXOMO_BUNDLE_SHA256=([^\r\n]+)/m);
            if (!versionMatch || !shaMatch) throw new Error(_('Не удалось определить SHA bundle Mixomo'));
            return self.getMixomoState().then(function(local) {
                self.mixomoVersion = local;
                self.setMixomoTitle();
                self.mixomoAvailableSha = shaMatch[1].trim();
                if (!isManual) return;
                if (local.sha === self.mixomoAvailableSha) {
                    self.setMixomoButtonIdle();
                    ui.addNotification(null, E('p', _('Установлена самая актуальная версия')), 'info');
                    return;
                }
                button.disabled = false;
                button.className = 'btn cbi-button-action';
                button.textContent = _('Установить обновление');
                button.onclick = function(ev) { ev.stopPropagation(); self.installMixomoUpdate(); };
                ui.addNotification(null, E('p', _('Доступно обновление Mixomo') + ': ' + versionMatch[1].trim()), 'info');
            });
        }).catch(function(err) {
            if (!isManual) return;
            self.setMixomoButtonIdle();
            ui.addNotification(null, E('p', err.message || _('Ошибка проверки обновлений Mixomo')), 'error');
        });
    },

    installMixomoUpdate: function() {
        var self = this;
        var button = this.mixomoUpdateButton;
        if (!button || this.mixomoBusy) return;
        var marker = '/tmp/mixomo-mixomo-task.rc';
        var log = '/tmp/mixomo-mixomo-task.log';
        var installer = '/tmp/mixomo-update.sh';
        var url = this.mixomoInstallerUrl();
        var manifest = this.mixomoManifestUrl();
        this.mixomoBusy = true;
        button.disabled = true;
        button.className = 'btn cbi-button-action';
        button.textContent = _('Ожидайте...');
        if (this.mixomoChannelSelect) this.mixomoChannelSelect.disabled = true;
        var command = 'rm -f ' + marker + ' ' + log + '; ' +
            '( wget -qO ' + installer + ' -T 300 "' + url + '" && chmod 700 ' + installer +
             ' && MAGITRICKLE="$(sed -n "1p" /etc/mixomo/versions/magitrickle 2>/dev/null)" MIXOMO_MANIFEST_PATH="' + manifest + '" MIXOMO_UPDATE_ONLY=1 sh ' + installer +
            ' </dev/null > ' + log + ' 2>&1; printf "%s" "$?" > ' + marker + ' ) >/dev/null 2>&1 &';
        var readMarker = function() { return fs.exec('/bin/sh', ['-c', 'cat ' + marker + ' 2>/dev/null']).then(function(res) { return (res && res.stdout) || ''; }).catch(function() { return ''; }); };
        var readTail = function() { return fs.exec('/bin/sh', ['-c', 'tail -20 ' + log + ' 2>/dev/null']).then(function(res) { return (res && res.stdout) || ''; }).catch(function() { return ''; }); };
        fs.exec('/bin/sh', ['-c', command]).then(function() {
            var started = Date.now();
            var wait = function() {
                if (Date.now() - started > 600000) throw new Error(_('Превышено время ожидания операции Mixomo'));
                return readMarker().then(function(result) {
                    if (!String(result).trim()) return new Promise(function(resolve) { setTimeout(function() { resolve(wait()); }, 1000); });
                    if (String(result).trim() !== '0') return readTail().then(function(out) { throw new Error(String(out || '').trim() || _('Не удалось установить Mixomo')); });
                });
            };
            return wait();
        }).then(function() {
            self.mixomoBusy = false;
            if (self.mixomoChannelSelect) self.mixomoChannelSelect.disabled = false;
            return self.getMixomoState();
        }).then(function(state) {
            self.mixomoVersion = state;
            self.setMixomoTitle();
            self.setMixomoButtonIdle();
            ui.addNotification(null, E('p', _('Mixomo обновлён')), 'info');
            if (confirm(_('Mixomo обновлён. Перезагрузить страницу?'))) window.location.reload();
        }).catch(function(err) {
            self.mixomoBusy = false;
            if (self.mixomoChannelSelect) self.mixomoChannelSelect.disabled = false;
            self.setMixomoButtonIdle();
            ui.addNotification(null, E('p', err.message || _('Ошибка обновления Mixomo')), 'error');
            self.refreshMagitrickle();
            self.refreshOverview();
        });
    },

    setMagitrickleButtonIdle: function() {
        var button = this.magitrickleUpdateButton;
        if (!button) return;
        var self = this;
        button.disabled = false;
        button.className = 'btn cbi-button-neutral mihomo-overview-card-action';
        button.textContent = _('Проверить обновление');
        button.onclick = function(ev) { ev.stopPropagation(); self.checkMagiTrickleUpdates(true); };
    },

    getMagitrickleVersion: function() {
        return fs.read('/etc/mixomo/versions/magitrickle').catch(function() { return ''; }).then(function(state) {
            var stored = String(state || '').replace(/^[^\n]*\n/, '').trim().replace(/[-_]r\d+$/i, '').replace(/-\d+$/, '');
            var storedMatch = stored.match(/v?[0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*/);
            if (storedMatch) { var sv = String(storedMatch[0]).replace(/[-_]r\d+$/i, '').replace(/-\d+$/, ''); return sv.indexOf('v') === 0 ? sv : 'v' + sv; }
            var cmd = 'if command -v timeout >/dev/null 2>&1; then timeout 5 magitrickled --version 2>&1; else magitrickled --version 2>&1; fi';
            return fs.exec('/bin/sh', ['-c', cmd]).then(function(res) {
                var output = (((res && res.stdout) || '') + '\n' + ((res && res.stderr) || '')).replace(/\x1b\[[0-9;]*m/g, '');
                var match = output.match(/version[= ]+v?([0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*)/i);
                if (match) { var bv = String(match[1]).replace(/[-_]r\d+$/i, '').replace(/-\d+$/, ''); return 'v' + bv; }
                return 'Неизвестно';
            }).catch(function() { return 'Неизвестно'; });
        });
    },

    finalizeMagitrickleUpdate: function(requestedVariant, fallbackVersion) {
        var self = this;
        self.magitrickleBusy = false;
        if (this.magitrickleVariantSelect) this.magitrickleVariantSelect.disabled = false;
        return fs.read('/etc/mixomo/versions/magitrickle').catch(function() { return ''; }).then(function(state) {
            var lines = String(state || '').split('\n');
            var fileVariant = (lines[0] || '').trim();
            var fileVersion = (lines[1] || '').trim();
            if (requestedVariant && fileVariant && fileVariant !== requestedVariant) {
                throw new Error(requestedVariant === 'mod' ? _('Не удалось переключиться на вариант Mod') : _('Не удалось переключиться на вариант Original'));
            }
            var variant = fileVariant || requestedVariant || self.magitrickleTargetVariant || self.magitrickleVariant || 'original';
            var version = fileVersion || fallbackVersion || '';
            self.magitrickleVariant = variant === 'mod' ? 'mod' : 'original';
            self.magitrickleTargetVariant = null;
            self.magitrickleVersion = version ? (String(version).indexOf('v') === 0 ? String(version) : 'v' + version) : _('Неизвестно');
            var title = self.overviewPanel ? self.overviewPanel.querySelector('[data-mihomo-card="magitrickle"] .mihomo-overview-card-title') : null;
            if (title) title.textContent = _('MagiTrickle') + ' ' + self.magitrickleVersion;
            self.setMagitrickleButtonIdle();
            return fs.exec('/bin/sh', ['-c', 'service magitrickle status 2>&1; pidof magitrickled 2>/dev/null; true']).catch(function() { return { code: 1 }; }).then(function(st) {
                self.magitrickleRunning = isMagiRunningOutput(st);
                if (self.overviewPanel && self.activeView === 'overview') return self.refreshOverview();
            });
        });
    },

    checkMagiTrickleUpdates: function(isManual) {
        var self = this;
        var button = this.magitrickleUpdateButton;
        if (!button) return;
        if (isManual) {
            button.disabled = true;
            button.className = 'btn cbi-button-action mihomo-overview-card-action';
            button.textContent = _('Проверка обновлений...');
        }
         var versionCommand = this.magitrickleVariant === 'mod'
             ? "if command -v curl >/dev/null 2>&1; then curl -fsSL --connect-timeout 10 --max-time 30 https://api.github.com/repos/badigit/MagiTrickle_mod_badigit/releases/latest; else wget -qO- -T 30 https://api.github.com/repos/badigit/MagiTrickle_mod_badigit/releases/latest; fi | grep -m1 '\"tag_name\"' | sed 's/.*\"tag_name\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/'"
             : 'if command -v apk >/dev/null 2>&1; then apk update >/dev/null 2>&1; apk policy magitrickle; else opkg update >/dev/null 2>&1; opkg list magitrickle; fi';
         fs.exec('/bin/sh', ['-c', versionCommand]).then(function(res) {
             if (!res || res.code !== 0) throw new Error((res && (res.stderr || res.stdout)) || _('Не удалось получить версию MagiTrickle'));
             var output = (res && res.stdout) || '';
             var match = self.magitrickleVariant === 'mod'
                 ? output.match(/v?([0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*)/)
                 : (output.match(/^\s*([0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*)\s*:/m) || output.match(/^magitrickle\s+-\s+([0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.\-]*)/m));
              var available = match ? match[1] : '';
              available = String(available || '').replace(/[-_]r\d+$/i, '').replace(/-\d+$/, '');
             if (!available) throw new Error(_('Не удалось определить доступную версию MagiTrickle'));
            self.magitrickleAvailableVersion = available;
            if (self.compareMagiVersions(available, self.magitrickleVersion) > 0) {
                button.disabled = false;
                button.className = 'btn cbi-button-action mihomo-overview-card-action';
                button.textContent = _('Установить обновление');
                button.onclick = function(ev) { ev.stopPropagation(); self.installMagiTrickleUpdate(); };
                ui.addNotification(null, E('p', _('Доступно обновление MagiTrickle') + ': v' + available), 'info');
                if (isManual) self.installMagiTrickleUpdate();
            } else {
                self.setMagitrickleButtonIdle();
                if (isManual) ui.addNotification(null, E('p', _('Установлена самая актуальная версия')), 'info');
            }
        }).catch(function(err) {
            if (!isManual) return;
            self.setMagitrickleButtonIdle();
            button.textContent = _('Ошибка. Повторить обновление?');
            button.onclick = function(ev) { ev.stopPropagation(); self.checkMagiTrickleUpdates(true); };
            ui.addNotification(null, E('p', err.message || _('Ошибка обновления MagiTrickle')), 'error');
        });
    },

    installMagiTrickleUpdate: function() {
        var self = this;
        var button = this.magitrickleUpdateButton;
        if (!button) return;
        var variant = this.magitrickleVariant;
        var latest = this.magitrickleAvailableVersion;
        button.disabled = true;
        button.className = 'btn cbi-button-action mihomo-overview-card-action';
        button.textContent = _('Ожидайте...');
        self.magitrickleBusy = true;
        self.magitrickleTargetVariant = variant;
        if (this.magitrickleVariantSelect) this.magitrickleVariantSelect.disabled = true;
        var busyCard = this.overviewPanel ? this.overviewPanel.querySelector('[data-mihomo-card="magitrickle"]') : null;
        if (busyCard) {
            var busyBtns = busyCard.querySelectorAll('button');
            for (var bi = 0; bi < busyBtns.length; bi++) {
                if (busyBtns[bi] !== button) busyBtns[bi].disabled = true;
            }
        }
        this.createAutomaticBackup('magitrickle').then(function() {
            return self.runMagitrickleSteps(self.magitrickleInstallSteps(variant));
        }).then(function() {
            return self.finalizeMagitrickleUpdate(variant, latest);
        }).then(function() {
            ui.addNotification(null, E('p', _('MagiTrickle обновлён')), 'info');
        }).catch(function(err) {
            self.magitrickleBusy = false;
            self.magitrickleTargetVariant = null;
            if (self.magitrickleVariantSelect) self.magitrickleVariantSelect.disabled = false;
            self.setMagitrickleButtonIdle();
            ui.addNotification(null, E('p', err.message || _('Ошибка установки MagiTrickle')), 'error');
            self.refreshMagitrickle();
        });
    },

    switchMagiTrickleVariant: function(variant, select) {
        var self = this;
        if (variant !== 'original' && variant !== 'mod') return;
        if (variant === this.magitrickleVariant) return;
        if (!confirm(_('Переключить вариант MagiTrickle? Компонент будет переустановлен.'))) {
            select.value = this.magitrickleVariant;
            return;
        }
        select.disabled = true;
        if (self.magitrickleUpdateButton) {
            self.magitrickleUpdateButton.disabled = true;
            self.magitrickleUpdateButton.className = 'btn cbi-button-action mihomo-overview-card-action';
            self.magitrickleUpdateButton.textContent = _('Ожидайте...');
        }
        if (self.overviewPanel) {
            var switchCard = self.overviewPanel.querySelector('[data-mihomo-card="magitrickle"]');
            if (switchCard) {
                var switchBtns = switchCard.querySelectorAll('button');
                for (var sbi = 0; sbi < switchBtns.length; sbi++) switchBtns[sbi].disabled = true;
            }
        }
        self.magitrickleTargetVariant = variant;
        self.magitrickleBusy = true;
        self.createAutomaticBackup('magitrickle').then(function() {
            return self.runMagitrickleSteps(self.magitrickleInstallSteps(variant));
        }).then(function() {
            return self.finalizeMagitrickleUpdate(variant, null);
        }).then(function() {
            ui.addNotification(null, E('p', _('MagiTrickle обновлён')), 'info');
        }).catch(function(err) {
            self.magitrickleBusy = false;
            self.magitrickleTargetVariant = null;
            if (self.magitrickleVariantSelect) self.magitrickleVariantSelect.disabled = false;
            select.value = self.magitrickleVariant;
            self.setMagitrickleButtonIdle();
            ui.addNotification(null, E('p', err.message || _('Не удалось переключить вариант MagiTrickle')), 'error');
            self.refreshMagitrickle();
        });
    },

    handleMagiTrickleAction: function(act) {
         var self = this;
         ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Выполнение...'))]);
         self.magitrickleRunning = act !== 'stop';
         if (self.overviewPanel && self.activeView === 'overview') self.refreshOverview();
         var prepare = (act === 'start' || act === 'restart') ? fs.exec('/bin/sh', ['-c', this.magitrickleKillStale()]) : Promise.resolve();
         prepare.then(function() {
            return fs.exec('/bin/sh', ['-c', self.magitrickleService(act)]);
        }).then(function() {
            return self.refreshMagitrickle();
        }).then(function() {
            ui.hideModal();
        }).catch(function(e) { ui.hideModal(); ui.addNotification(null, E('p', e.message), 'error'); });
    },

    handleServiceAction: function(act) {

		if (!VALID_ACTIONS.includes(act)) return;
		var self = this;
		ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Выполнение...'))]);
		fs.exec('/etc/init.d/mihomo', [act]).then(function() {
			self.isRunning = act !== 'stop';
			return self.getMihomoVersion();
		}).then(function(version) {
			self.currentVersion = version;
			if (self.overviewPanel && self.activeView === 'overview') self.refreshOverview();
			ui.hideModal();
		}).catch(function(e) { ui.hideModal(); ui.addNotification(null, E('p', e.message), 'error'); });
	},
    
    handleShowLogs: function() {
        var self = this;
        fs.exec('/sbin/logread', ['-e', 'mihomo']).then(function(res) {
            var logContent = res.stdout;
            if (!logContent && res.code !== 0) {
                logContent = _("Записей о 'mihomo' в системном журнале не найдено.\nВозможно, служба не запущена.");
            } else if (!logContent) {
                logContent = _('Журнал пуст.');
            }

            self.showOutput(logContent, false);
        }).catch(function(err) {
            self.showOutput(_('Ошибка чтения журнала: ') + err.message, true);
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
