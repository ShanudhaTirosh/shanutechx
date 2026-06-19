[English](/README.md)

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./media/shanutechx-dark.png">
    <img alt="SHANUTECHX" src="./media/shanutechx-light.png">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/ShanudhaTirosh/shanutechx/releases"><img src="https://img.shields.io/github/v/release/ShanudhaTirosh/shanutechx" alt="Release"></a>
  <a href="https://github.com/ShanudhaTirosh/shanutechx/actions"><img src="https://img.shields.io/github/actions/workflow/status/ShanudhaTirosh/shanutechx/release.yml.svg" alt="Build"></a>
  <a href="#"><img src="https://img.shields.io/github/go-mod/go-version/ShanudhaTirosh/shanutechx.svg" alt="GO Version"></a>
  <a href="https://github.com/ShanudhaTirosh/shanutechx/releases/latest"><img src="https://img.shields.io/github/downloads/ShanudhaTirosh/shanutechx/total.svg" alt="Downloads"></a>
  <a href="https://www.gnu.org/licenses/gpl-3.0.en.html"><img src="https://img.shields.io/badge/license-GPL%20V3-blue.svg?longCache=true" alt="License"></a>
</p>

**SHANUTECHX** is a glassmorphism-styled, fully rebranded web control panel for managing [Xray-core](https://github.com/XTLS/Xray-core) servers. Built on top of the [3x-ui](https://github.com/MHSanaei/3x-ui) engine, it adds a modern deep-navy + violet/cyan glass UI, a custom branded subscription page, automated Nginx SNI routing, REALITY + VLESS+TLS inbound seeding, and a one-command install script — all without touching the underlying engine, database schema, or binary so upstream updates can still be merged cleanly.

> [!IMPORTANT]
> This project is intended for personal use only. Please do not use it for illegal purposes or in a production environment.

---

## What's different from 3x-ui

| Feature | 3x-ui (upstream) | SHANUTECHX |
|---|---|---|
| UI theme | Default dark / light | Glassmorphism — brand violet `#7A43D7` → cyan `#23B6D3` |
| Subscription page | Built-in plain page | Custom branded glass page with QR codes, traffic ring, deep-links |
| Install script | Generic `install.sh` | `shanutechx-install.sh` — Nginx SNI router, REALITY + VLESS+TLS seeds, DNS validation |
| Nginx architecture | Not included | Stream SNI map (REALITY / VLESS-TLS / Panel on single :443) |
| Inbound seeding | Manual | Two inbounds pre-seeded at install (REALITY + normal VLESS+TLS) |
| Favicons | Default | Custom brand favicons |
| Engine / binary | `x-ui` | `x-ui` (unchanged — skin only) |

---

## Features

- **Multi-protocol inbounds** — VLESS, VMess, Trojan, Shadowsocks, WireGuard, Hysteria2, HTTP, SOCKS (Mixed), Dokodemo-door / Tunnel, and TUN.
- **Modern transports & security** — TCP (Raw), mKCP, WebSocket, gRPC, HTTPUpgrade, and XHTTP, secured with TLS, XTLS, and REALITY.
- **Fallbacks** — serve multiple protocols on a single port using Xray's fallback support.
- **Per-client management** — traffic quotas, expiry dates, IP limits, live online status, one-click share links, QR codes, and subscriptions.
- **Traffic statistics** — per inbound, per client, and per outbound, with reset controls.
- **Multi-node support** — manage and scale across multiple servers from a single panel.
- **Outbound & routing** — WARP, NordVPN, custom routing rules, load balancers, and outbound proxy chaining.
- **Branded subscription server** — custom glassmorphism page with inline QR generator, traffic ring, and deep-link Open-in buttons for v2rayNG, Shadowrocket, sing-box, Clash Meta, Streisand, and Hiddify.
- **Telegram bot** for remote monitoring and management.
- **RESTful API** with in-panel Swagger documentation at `/<panelPath>/api-docs`.
- **Flexible storage** — SQLite (default) or PostgreSQL.
- **13 UI languages** with dark and light themes.
- **Fail2ban integration** for enforcing per-client IP limits.
- **Automated Nginx SNI routing** — REALITY, VLESS+TLS, and panel all share port 443 via `ssl_preread`.

---

## Quick Install

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ShanudhaTirosh/shanutechx/main/shanutechx-install.sh) -install y
```

Or with all flags at once (no prompts):

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ShanudhaTirosh/shanutechx/main/shanutechx-install.sh) \
  -install y \
  -panel_domain panel.yourdomain.com \
  -reality_domain reality.yourdomain.com \
  -vless_sni www.cloudflare.com
```

During installation the script will:
1. Validate DNS records for your domains
2. Issue Let's Encrypt certificates via Certbot
3. Write and test the Nginx stream SNI config
4. Download and install the SHANUTECHX panel binary
5. Seed two inbounds (REALITY + VLESS+TLS) with a generated x25519 keypair
6. Deploy the branded subscription page template
7. Prompt for your panel username and password (never hardcoded)
8. Print a one-time summary with all URLs, credentials, and the API token

After installation run `x-ui` to open the management menu.

---

## Nginx Architecture

All traffic enters on port **443**. Nginx reads the SNI before terminating TLS and routes:

```
Client → :443
  ├─ SNI = reality.yourdomain.com  →  Xray REALITY inbound  (port 8443)
  ├─ SNI = <vless_sni>             →  Xray VLESS+TLS inbound (random high port)
  ├─ SNI = panel.yourdomain.com    →  Nginx HTTPS (port 7443) → panel UI
  └─ default (anything else)       →  Xray REALITY (panel stays hidden)
```

Panel is **never** reachable by IP scan — only via the exact panel domain SNI.

---

## REALITY inbound (seeded at install)

| Field | Value |
|---|---|
| Protocol | VLESS |
| Network | TCP |
| Security | REALITY |
| Port | 8443 (Nginx-fronted) |
| Server names | `<reality_domain>` |
| Fingerprint | chrome |
| Flow | xtls-rprx-vision |
| Keys | Fresh x25519 keypair generated at install |

---

## VLESS + TLS inbound (seeded at install)

| Field | Value |
|---|---|
| Protocol | VLESS |
| Network | TCP |
| Security | TLS |
| Port | Random high port (Nginx-fronted) |
| SNI / cert | Real Let's Encrypt cert if you own the SNI domain; self-signed + allowInsecure if you don't |

> **Trust trade-off (clearly stated during install):**
> - Own the SNI domain → Certbot issues a real cert → best security, no client warnings.
> - Camouflage a domain you don't own (e.g. `www.cloudflare.com`) → self-signed cert → works, but detectable by TLS inspection; clients must enable `allowInsecure`.

---

## Subscription Page

The branded subscription page is a self-contained Go template (`sub_templates/shanutechx/index.html`) served by the panel's native template engine. No CDN dependencies — everything is inline.

Features:
- Glassmorphism design matching the panel palette
- SVG traffic ring (used / remaining, animated)
- QR code per protocol link (pure JS generator, no external API)
- Copy button with toast notification
- Deep-link "Open In" buttons: v2rayNG, Streisand, Shadowrocket, sing-box, Clash Meta, Hiddify
- Expiry countdown with colour warning
- Mobile-first responsive layout

---

## API

The panel ships a full REST API. Interactive Swagger UI is at:

```
https://<panel_domain>/<panelPath>/api-docs
```

Quick examples (replace values from your install summary):

```bash
export API="https://panel.yourdomain.com/YOUR_PATH/api"
export TOKEN="your-48-char-api-token"

# Server status
curl -s -H "Authorization: Bearer $TOKEN" "$API/server/status" | jq .

# List inbounds
curl -s -H "Authorization: Bearer $TOKEN" "$API/inbounds" | jq '.obj[] | {id,remark,port}'

# Add a client
curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  "$API/inbounds/1/client" \
  -d '{"id":"<uuid>","email":"user@example.com","totalGB":50,"enable":true,"flow":"xtls-rprx-vision","subId":"<random>","reset":0}'
```

See [API.md](API.md) for the full reference with copy-paste curl examples.

---

## Uninstall

```bash
bash shanutechx-install.sh -uninstall y
```

Removes the panel, Nginx config, certificates config, subscription template, firewall rules, cron jobs, and service files. The Let's Encrypt certificates in `/etc/letsencrypt/` are left intact.

---

## Updating

```bash
# Re-run the installer — it detects the existing DB and updates without wiping clients
bash shanutechx-install.sh -install y \
  -panel_domain panel.yourdomain.com \
  -reality_domain reality.yourdomain.com
```

---

## Merging upstream 3x-ui updates

See [CHANGELOG-SHANUTECHX.md](CHANGELOG-SHANUTECHX.md) for the exact list of every file changed from upstream and how to re-apply the SHANUTECHX skin after a merge. The short version:

```bash
git remote add upstream https://github.com/MHSanaei/3x-ui.git
git fetch upstream
git merge upstream/main
# Fix conflicts using CHANGELOG-SHANUTECHX.md as your guide
# Then rebuild frontend + binary and push a new release
```

---

## Supported Platforms

**Operating systems:** Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12  
*(The installer explicitly checks for these. Other distros may work but are untested.)*

**Architectures:** `amd64` (install script) · `arm64` (manual build)

---

## Database Options

| Backend | When to use |
|---|---|
| **SQLite** (default) | Single server, personal use — zero setup, file at `/etc/x-ui/x-ui.db` |
| **PostgreSQL** | High client count or multi-node deployments |

Switch to PostgreSQL after install:

```bash
x-ui migrate-db --dsn "postgres://xui:password@127.0.0.1:5432/xui?sslmode=disable"
# then set in /etc/default/x-ui:
XUI_DB_TYPE=postgres
XUI_DB_DSN=postgres://xui:password@127.0.0.1:5432/xui?sslmode=disable
systemctl restart x-ui
```

---

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `XUI_DB_TYPE` | Database backend: `sqlite` or `postgres` | `sqlite` |
| `XUI_DB_DSN` | PostgreSQL connection string | — |
| `XUI_DB_FOLDER` | Directory for SQLite database file | `/etc/x-ui` |
| `XUI_INIT_WEB_BASE_PATH` | Initial URI path for the panel | `/` |
| `XUI_ENABLE_FAIL2BAN` | Enable Fail2ban IP-limit enforcement | `true` |
| `XUI_LOG_LEVEL` | Log verbosity (`debug` `info` `warning` `error`) | `info` |
| `XUI_DEBUG` | Enable debug mode | `false` |

---

## Supported Languages

English · فارسی · العربية · 中文（简体） · 中文（繁體） · Español · Русский · Українська · Türkçe · Tiếng Việt · 日本語 · Bahasa Indonesia · Português (Brasil)

---

## Credits

SHANUTECHX is built on top of [3x-ui](https://github.com/MHSanaei/3x-ui) by [MHSanaei](https://github.com/MHSanaei) and the original [alireza0](https://github.com/alireza0/). The engine, database schema, binary interface, and API are theirs — SHANUTECHX is a skin and deployment layer on top.

- [Iran v2ray rules](https://github.com/chocolate4u/Iran-v2ray-rules) (License: **GPL-3.0**)
- [Russia v2ray rules](https://github.com/runetfreedom/russia-v2ray-rules-dat) (License: **GPL-3.0**)
- [terraform-provider-3x-ui](https://github.com/batonogov/terraform-provider-threexui) (License: **MIT**)

---

## Stargazers over Time

[![Stargazers over time](https://starchart.cc/ShanudhaTirosh/shanutechx.svg?variant=adaptive)](https://starchart.cc/ShanudhaTirosh/shanutechx)
