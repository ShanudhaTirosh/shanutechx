# SHANUTECHX — REST API Quick Reference

The SHANUTECHX panel exposes the full 3x-ui REST API unchanged.
Interactive Swagger UI is available at:

```
https://PANEL_DOMAIN/<PANEL_PATH>/api-docs
```

---

## Authentication

All API calls require an `Authorization` header using the token generated at install time
(also displayed in the panel under **Settings → API Token**).

```bash
# Set once in your shell session
export STX_HOST="https://panel.example.com"
export STX_PATH="/your-panel-path"
export STX_TOKEN="your-api-token-here"

export API="${STX_HOST}${STX_PATH}/api"
```

---

## Core Calls

### 1 — Health / server status

```bash
curl -s -H "Authorization: Bearer $STX_TOKEN" \
  "$API/server/status" | jq .
```

### 2 — List all inbounds

```bash
curl -s -H "Authorization: Bearer $STX_TOKEN" \
  "$API/inbounds" | jq '.obj[] | {id,remark,port,protocol}'
```

### 3 — Get a single inbound (ID=1)

```bash
curl -s -H "Authorization: Bearer $STX_TOKEN" \
  "$API/inbounds/1" | jq .
```

### 4 — Add a client to an inbound

Replace `INBOUND_ID` with the numeric ID from `GET /api/inbounds`.

```bash
curl -s -X POST \
  -H "Authorization: Bearer $STX_TOKEN" \
  -H "Content-Type: application/json" \
  "$API/inbounds/INBOUND_ID/client" \
  -d '{
    "id": "00000000-0000-0000-0000-000000000000",
    "flow": "xtls-rprx-vision",
    "email": "alice@example.com",
    "limitIp": 0,
    "totalGB": 100,
    "expiryTime": 0,
    "enable": true,
    "tgId": "",
    "subId": "alice-unique-sub-id",
    "reset": 0
  }' | jq .
```

**Field notes:**
- `id`: UUIDv4. Generate with `uuidgen` or `python3 -c "import uuid; print(uuid.uuid4())"`.
- `email`: unique label shown in the panel (does not need to be a real email).
- `totalGB`: 0 = unlimited.
- `expiryTime`: Unix timestamp in milliseconds, 0 = never.
- `subId`: short string used to build the client subscription URL.
- `flow`: required for VLESS+REALITY (`xtls-rprx-vision`); omit for plain VLESS.

### 5 — Update a client (by UUID)

```bash
curl -s -X POST \
  -H "Authorization: Bearer $STX_TOKEN" \
  -H "Content-Type: application/json" \
  "$API/inbounds/INBOUND_ID/client/00000000-0000-0000-0000-000000000000" \
  -d '{"totalGB": 200, "expiryTime": 0, "enable": true}' | jq .
```

### 6 — Delete a client

```bash
curl -s -X POST \
  -H "Authorization: Bearer $STX_TOKEN" \
  "$API/inbounds/INBOUND_ID/client/00000000-0000-0000-0000-000000000000/del" | jq .
```

### 7 — List clients + traffic for an inbound

```bash
curl -s -H "Authorization: Bearer $STX_TOKEN" \
  "$API/inbounds/1/client/stats" | jq '.obj[] | {email, up, down, total}'
```

### 8 — Reset a client's traffic counters

```bash
curl -s -X POST \
  -H "Authorization: Bearer $STX_TOKEN" \
  "$API/inbounds/INBOUND_ID/client/00000000-0000-0000-0000-000000000000/resetClientIpLimitAndTraffic" | jq .
```

### 9 — Get a client's subscription URL

```bash
# Build it from the sub path + subId:
echo "${STX_HOST}${STX_PATH}/sub/alice-unique-sub-id"
# or JSON variant:
echo "${STX_HOST}${STX_PATH}/sub/alice-unique-sub-id/json"
# or Clash:
echo "${STX_HOST}${STX_PATH}/sub/alice-unique-sub-id/clash"
```

### 10 — Restart Xray core

```bash
curl -s -X POST \
  -H "Authorization: Bearer $STX_TOKEN" \
  "$API/server/restartXrayService" | jq .
```

### 11 — Get Xray core version / log

```bash
curl -s -H "Authorization: Bearer $STX_TOKEN" \
  "$API/server/getXrayVersion" | jq .

curl -s -H "Authorization: Bearer $STX_TOKEN" \
  "$API/server/getLogs?count=50&level=warning" | jq .
```

### 12 — Backup the database

```bash
curl -s -H "Authorization: Bearer $STX_TOKEN" \
  "$API/server/getDb" -o shanutechx-backup.db
```

---

## Automation pattern: auto-provision on signup

```bash
#!/usr/bin/env bash
# Usage: ./provision.sh alice@example.com 50
EMAIL="$1"
QUOTA_GB="${2:-50}"
UUID=$(python3 -c "import uuid; print(uuid.uuid4())")
SUBID=$(python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_lowercase+string.digits) for _ in range(16)))")

curl -s -X POST \
  -H "Authorization: Bearer $STX_TOKEN" \
  -H "Content-Type: application/json" \
  "$API/inbounds/1/client" \
  -d "{
    \"id\":\"$UUID\",
    \"email\":\"$EMAIL\",
    \"limitIp\":2,
    \"totalGB\":$QUOTA_GB,
    \"expiryTime\":0,
    \"enable\":true,
    \"tgId\":\"\",
    \"subId\":\"$SUBID\",
    \"flow\":\"xtls-rprx-vision\",
    \"reset\":0
  }" | jq .

echo "Subscription URL: ${STX_HOST}${STX_PATH}/sub/${SUBID}"
```

---

## Notes

- All endpoints return `{ "success": true/false, "msg": "...", "obj": ... }`.
- The API token does **not** expire unless regenerated from the panel Settings page.
- Rate limiting is enforced per-IP by the panel's login guard (not by the API endpoints themselves).
- See the interactive Swagger UI at `https://PANEL_DOMAIN/PANEL_PATH/api-docs` for the full schema.
