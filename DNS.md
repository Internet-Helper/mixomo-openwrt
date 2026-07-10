Убедитесь, что в файле `/etc/dnsmasq.conf` нет строк, конфликтующих с конфигурацией ниже.  
Если никогда не меняли этот файл или убедились что конфликтов нет, откройте консоль роутера и вставьте следующий код:
```
cat >> /etc/dnsmasq.conf << 'EOF'
strict-order
no-resolv
server=127.0.0.1#3053
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

*Готово! Вы великолепны!*  

### Итог

- Провайдер не сможет подменять DNS‑ответы (DNS spoofing), если первым в списке DNS указан Mihomo или отдельный пакет, обеспечивающий шифрование DNS‑запросов (DoH, DoH/3, DoT, DoQ).  
Некоторые провайдеры делают подмену принудительно - даже при использовании публичных нешифрованных DNS‑серверов.
- Если ваш провайдер не занимается подменой DNS, можно отправлять запросы к 8.8.8.8 и другим серверам ниже по списку.  
В этом случае вы будете получать актуальные IP‑адреса для многих ресурсов (например, YouTube), тогда как провайдерские DNS, скорее всего, не будут возвращать актуальные адреса.

> [!TIP]
> Комментарии с объяснением кода:  

```
cat >> /etc/dnsmasq.conf << 'EOF'   # Запись в конец файла службы dnsmasq (отвечает за работу с DNS)
strict-order                        # Служба dnsmasq будет опрашивать DNS‑серверы строго сверху вниз
no-resolv                           # Запрещает использовать другие DNS (из /etc/resolv.conf)
server=127.0.0.1#3053               # 1 DNS - секция DNS в Mihomo (порт 3053 можно менять на другой)
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
> Если в конфигурации Mihomo нет секции DNS, вставьте её самостоятельно:  

```

dns:
  enable: true
  listen: 0.0.0.0:3053 # Порт 3053 можно менять на любой свободный
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
