## Инструкция  
Убедитесь, что в файле `/etc/dnsmasq.conf` нет строк, конфликтующих с конфигурацией ниже.  
Если никогда не меняли этот файл или убедились, что конфликтов нет, откройте консоль роутера, скопируйте и вставьте следующий код:
```
cat >> /etc/dnsmasq.conf << 'EOF'
strict-order
no-resolv
server=127.0.0.1#7880
server=8.8.8.8
server=8.8.4.4
server=1.1.1.1
server=1.0.0.1
server=9.9.9.9
server=149.112.112.112
server=94.140.14.140
server=94.140.14.141
server=77.88.8.8
server=77.88.8.1
EOF
service dnsmasq restart
```
 
Маленькое дополнение, если частично блокируют загрузки с GitHub:

```
cat >> /etc/dnsmasq.conf << 'EOF'
address=/raw.githubusercontent.com/185.199.108.133
address=/raw.githubusercontent.com/185.199.109.133
EOF
service dnsmasq restart
```

*Готово! Вы великолепны!* На этом всё.  
Информация ниже не является обязательной и предоставлена лишь для более глубокого понимания темы.

## Пояснения

Некоторые провайдеры делают **принудительную** подмену DNS‑ответов при использовании **нешифрованных** и **публичных** DNS‑серверов.  
Это означает, что невозможно получить актуальные адреса для захода на ряд сайтов даже если вы обращаетесь к 8.8.8.8 или аналогичным DNS.  
Один из способов проверить, есть ли подмена DNS-ответов у Вашего провайдера, это временно удалить обращение к секции шифрованных DNS в Mihomo и запросить адрес YouTube через нешифрованный и публичный DNS в консоли:
```
sed -i '/server=127\.0\.0\.1#7880/d' /etc/dnsmasq.conf
service dnsmasq restart
nslookup youtube.com
```
Если не увидите список IP-адресов - значит подмена существует.  
Чтобы вернуть настройки в исходное состояние:
```
sed -i '/server=8\.8\.8\.8/i server=127.0.0.1#7880' /etc/dnsmasq.conf
service dnsmasq restart
```
*(Команда найдет строку server=8.8.8.8 и вернет над ней server=127.0.0.1#7880)*  

Провайдеры не могут принудительно подменять DNS‑ответы, если запрос идет через **шифрованные** DNS.  
Существуют следующие типы шифрованных DNS:  
  - DNS over HTTPS (DoH)  
  - DNS over HTTPS/3 (DoH/3)  
  - DNS over TLS (DoT)  
  - DNS over QUIC (DoQ)  

Если ваш провайдер не занимается подменой DNS-ответов, можно отправлять запросы к 8.8.8.8 или другим нешифрованным серверам.  

> [!TIP]
> Комментарии с объяснением кода:  

```
cat >> /etc/dnsmasq.conf << 'EOF'   # Запись в конец файла службы dnsmasq (отвечает за работу с DNS)
strict-order                        # Служба dnsmasq будет опрашивать DNS‑серверы строго сверху вниз
no-resolv                           # Запрещает использовать другие DNS (из /etc/resolv.conf)
server=127.0.0.1#7880               # 1 DNS - секция шифрованных DNS в Mihomo (порт 7880 можно менять на другой)
server=8.8.8.8                      # 2 DNS - Google
server=8.8.4.4                      # 3 DNS - Google
server=1.1.1.1                      # 4 DNS - Cloudflare
server=1.0.0.1                      # 5 DNS - Cloudflare
server=9.9.9.9                      # 6 DNS - Quad9
server=149.112.112.112              # 7 DNS - Quad9
server=94.140.14.140                # 8 DNS - AdGuard
server=94.140.14.141                # 9 DNS - AdGuard
server=77.88.8.8                    # 10 DNS - Yandex
server=77.88.8.1                    # 11 DNS - Yandex
EOF                                 # Конец записи
service dnsmasq restart             # Перезапуск службы dnsmasq
```

> [!TIP]
> Если в конфигурации Mihomo нет секции шифрованных DNS, вставьте её самостоятельно:  

```
dns:
  enable: true
  listen: 0.0.0.0:7880 # Порт 7880 нужно менять на тот, что указан в server=127.0.0.1#....
  ipv6: false
  nameserver:
    - https://8.8.8.8/dns-query
    - https://8.8.4.4/dns-query
    - https://1.1.1.1/dns-query
    - https://1.0.0.1/dns-query
    - https://9.9.9.9/dns-query
    - https://149.112.112.112/dns-query
    - https://94.140.14.140/dns-query
    - https://94.140.14.141/dns-query
    - https://77.88.8.8/dns-query
    - https://77.88.8.1/dns-query
```
