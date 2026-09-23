<div align="center">
  <img src="https://github.com/user-attachments/assets/1f74035d-8be0-4cac-9670-54dbad1ccd56" width="20" alt="Telegram">
  <a href="https://t.me/Inter_net_Helper/8872">Telegram group</a> for questions or discussion
</div>

<div align="center">
  <img src="https://github.com/user-attachments/assets/b74aab60-2d5e-40de-a688-0eb3a58cbe11" width="20" alt="Money"> You can show your appreciation via
  <a href="https://pay.cloudtips.ru/p/8ec8a87c">CloudTips</a> or <a href="https://yoomoney.ru/to/41001945296522">YooMoney</a>
</div>
<br>

<img width="1920" height="478" alt="1" src="https://github.com/user-attachments/assets/d3ae54a4-5db1-4395-84c7-40600bf1718c" />

## Description

**Mixomo-OpenWrt** is an automated installer for three components that provide smart traffic routing on OpenWrt routers:

- [Mihomo](https://github.com/MetaCubeX/mihomo) — a multifunctional proxy core
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) — a tun <-> socks5 bridge required to connect Mihomo Original with MagiTrickle
- [MagiTrickle](https://github.com/MagiTrickle/MagiTrickle) | [MagiTrickle Mod](https://github.com/badigit/MagiTrickle_mod_badigit) — routes only selected domains and addresses through the Mihomo proxy core

**What this provides in practice:**

- Only the traffic you explicitly route through the proxy goes through it
- All other traffic goes through your home ISP at full speed, bypassing the proxy core
- If necessary, local routing can be used to send all traffic from selected IPs/CIDRs to the Mihomo core

<img width="963" height="606" alt="2" src="https://github.com/user-attachments/assets/a5a0106b-ecd0-465f-8f13-7b2679c1656f" />

# Requirements

- OpenWrt 24.10+ or 25.12+
- Approximately 16 MB of temporary storage to download the Mihomo proxy core archive
- At least 18 MB of disk space for all required packages

# Installing the Latest Version

#### Command:
```sh
curl -fsSL https://github.com/Internet-Helper/mixomo-openwrt/raw/main/install.sh | sh
```

#### Alternative command:
```sh
wget -qO- https://github.com/Internet-Helper/mixomo-openwrt/raw/main/install.sh | sh
```

# Installing the Testing Version

#### Command:
```sh
curl -fsSL https://github.com/Internet-Helper/mixomo-openwrt/raw/main/test-install.sh | sh
```

#### Alternative command:
```sh
wget -qO- https://github.com/Internet-Helper/mixomo-openwrt/raw/main/test-install.sh | sh
```

#### What should you do after installation?

- **It is highly recommended** to change your DNS servers to public ones
- Open OpenWrt → Services → Mixomo → click “Configuration” in Mihomo and edit the configuration or create your own<br>
  The [official documentation](https://mihomo-docs.netlify.app/ru/config/) or the [web4core online generator](https://spatiumstas.github.io/web4core) may be helpful
- Click “MagiTrickle” and add websites to “Groups” or subscription links to “Subscriptions”<br>

# Uninstallation

#### Command:
```sh
curl -fsSL https://github.com/Internet-Helper/mixomo-openwrt/raw/main/delete.sh | sh
```

#### Alternative command:
```sh
wget -qO- https://github.com/Internet-Helper/mixomo-openwrt/raw/main/delete.sh | sh
```

# License

This project is distributed under the [Apache 2.0](https://github.com/Internet-Helper/mixomo-openwrt/blob/main/LICENSE) license.
