# CHANGELOG — SHANUTECHX deviations from stock 3x-ui

This file exists to help you merge future upstream 3x-ui releases cleanly.
Every deliberate change from the upstream source is listed here with its rationale
and the exact files touched. If the upstream changes one of these files, read this
first before overwriting.

---

## Versioning baseline

| Item               | Value                          |
|--------------------|-------------------------------|
| Upstream project   | 3x-ui                         |
| Baseline version   | v0.3.1                        |
| This skin version  | SHANUTECHX-1.0.0              |
| Engine binary      | unchanged (`x-ui`)            |
| Install path       | unchanged (`/usr/local/x-ui`) |
| DB schema          | unchanged                     |
| Go packages        | unchanged                     |
| systemd binary     | unchanged                     |

---

## Changes by file

### `frontend/index.html`
- Added `<title>SHANUTECHX</title>`
- Added `<link rel="icon">` for `favicon.svg` and `favicon.ico`
- Added Google Fonts preconnect + Inter/Manrope import

**Merge note:** upstream rarely touches this file. If it does, re-apply the
`<title>`, `<link rel="icon">`, and font `<link>` tags on top of any upstream changes.

---

### `frontend/login.html`
- Changed `<title>` from "Sign in" to "SHANUTECHX — Sign In"
- Added `<link rel="icon">` for both favicon assets
- Added font import

**Merge note:** same as index.html — cosmetic header tags only.

---

### `frontend/subpage.html`
- Changed `<title>` to "SHANUTECHX — Subscription"
- Added `<link rel="icon">` tags and font import

---

### `frontend/src/hooks/useTheme.tsx`
**This is the highest-impact change.** The entire file is replaced with a
SHANUTECHX-branded version that:
- Sets `colorPrimary` = `#7A43D7` (brand-violet)
- Sets `colorLink` / `colorInfo` = `#23B6D3` (brand-cyan)
- Uses semi-transparent `colorBgContainer` / `colorBgElevated` so AntD surfaces
  become glassmorphism-capable
- Applies a deep-navy body gradient via `applyDom()` in dark mode
- Exports `DARK_TOKENS`, `ULTRA_DARK_TOKENS`, `DARK_LAYOUT_TOKENS`, `DARK_MENU_TOKENS`,
  `DARK_CARD_TOKENS` (same names as upstream; drop-in compatible)
- Adds per-component AntD token overrides for Modal, Table, Input, Select, Tag, Progress, Button

**Merge note:** This is the most likely file to conflict. When merging upstream:
1. Apply upstream logic/API changes to the new version of this file.
2. Keep all brand color constants and `applyDom()` gradient.
3. The token names exported are unchanged from upstream; only values differ.

---

### `frontend/src/styles/utils.css`
- Added `.glass-panel` and `.glass-panel-elevated` with `backdrop-filter`
- Added `.brand-gradient-text`, `.brand-gradient-bg`, `.brand-gradient-border` helpers
- Added `.hover-lift` micro-interaction
- Added light-mode glass overrides
- Existing spacing/dot helpers are preserved unchanged

**Merge note:** Upstream changes to utils.css are rare. If they add helpers, append
them after the SHANUTECHX block at the bottom. The `.glass-panel` class is referenced
in all other CSS files.

---

### `frontend/src/styles/page-shell.css`
- `--bg-page` in dark mode changed from `#1a1b1f` to `transparent` (body gradient shows through)
- `--bg-page` in ultra-dark changed from `#000` to `transparent`
- Added glass `backdrop-filter` to `.ant-dropdown .ant-dropdown-menu`
- Active tab `.ant-tabs-ink-bar` now uses brand gradient
- Retained all upstream selectors verbatim

**Merge note:** When upstream adds new page class names (e.g. `.new-page`), add
the corresponding dark/ultra-dark/transparent entries in this file.

---

### `frontend/src/styles/page-cards.css`
- All `.ant-card` surfaces in dark mode get `backdrop-filter: blur(20px)` + semi-transparent background
- `.ant-modal-content` in dark mode gets glass treatment
- AntD Table header gets glass background
- Added hover lift (`translateY(-2px)`) on cards
- All upstream `border-radius` values replaced with `16px` (brand `--radius`)
- Light-mode glass added

**Merge note:** If upstream adds new card variants or modal styles, replicate
the dark-mode glass treatment on them here.

---

### `frontend/src/layouts/AppSidebar.css`
**Fully replaced.** Key changes from upstream:
- Sidebar sider uses `backdrop-filter: blur(20px)` glass instead of solid background
- `.sider-brand .brand-text` uses CSS gradient text (`background-clip: text`)
- Active nav item has a left-border gradient accent instead of a flat highlight
- Mobile: sidebar collapses to zero-width; `.drawer-handle` hamburger button appears
- Drawer content gets glass background
- All class names preserved from upstream; only styles changed

**Merge note:** If upstream restructures sidebar markup (adds/removes class names),
update the selectors in this file. The class `.sider-brand`, `.sider-nav`,
`.sider-footer`, `.sider-version` must match what `AppSidebar.tsx` emits.

---

### `frontend/src/pages/login/LoginPage.css`
**Fully replaced.** Key changes:
- Full-viewport dark gradient background (replaces upstream solid color)
- Animated violet/cyan blobs behind login card
- Glass card with `backdrop-filter`
- Gradient-text SHANUTECHX wordmark above the form
- Gradient submit button with hover lift
- Light mode variant (pale gradient + frosted white card)
- Entrance animation (`card-enter` keyframe)

**Merge note:** If upstream adds new elements to the login page (e.g. SSO buttons,
CAPTCHA), style them inside `.login-card` using the same glass/gradient language.

---

### `frontend/src/pages/login/TwoFactorModal.css`
**New file** (upstream may not have had this separate).
- Glass modal surface
- OTP input group with brand focus state
- Gradient submit button
- Shake animation on error

---

### `frontend/src/pages/index/StatusCard.css`
- Added hover lift
- Added `.stat-icon-wrap` (violet glow in dark mode)
- Added `.stat-label` / `.stat-value` typography helpers
- Existing progress-text overrides preserved

---

### `frontend/src/pages/index/XrayStatusCard.css`
- Added `running-dot` with brand-cyan pulse animation
- Added `.restart-btn` gradient styling
- Existing `.action`, `.error-line`, `.cursor-pointer` preserved

---

### `sub_templates/shanutechx/index.html` *(new file)*
**New artifact — not in upstream at all.**
A fully self-contained Go `html/template` subscription page:
- Uses all documented template variables (`{{ .subUrl }}`, `{{ .links }}`, etc.)
- Inline QR code generator (pure JS, no CDN)
- SVG traffic ring (animated, computed from byte values)
- Animated gradient blobs
- Per-link cards with copy + QR
- Deep-link "Open In" buttons for 6 common clients
- Subscription URL copy cards
- Mobile-first responsive layout

Point `Settings → Subscription → Sub Theme Directory` at the folder
containing this file (`/opt/shanutechx/sub_templates/shanutechx/`).

---

### `x-ui.service.debian` / `.arch` / `.rhel`
- `Description` changed from `x-ui Service` to `SHANUTECHX Panel Service`
- All other fields (`ExecStart`, `WorkingDirectory`, `User`, `Restart`) unchanged

**Merge note:** Upstream rarely changes service files. If it does, keep only
the `Description` change.

---

### `shanutechx-install.sh` *(new file)*
**Not in upstream.** Replaces the stock `install.sh` with:
- Full SHANUTECHX branding and ASCII banner
- Interactive + flag-based argument parsing
- DNS validation before cert issuance
- Nginx stream-SNI config (REALITY + normal VLESS+TLS routing)
- Database seeding (two inbounds, panel credentials, subscription settings, `subThemeDir`)
- Credential prompt (no hardcoded defaults)
- Idempotent re-run logic
- Uninstall path

**Merge note:** This script references the panel binary and DB paths by their
upstream names (`x-ui`, `/etc/x-ui/x-ui.db`, `/usr/local/x-ui`). When upgrading
the panel binary, update the download URL placeholder in `install_panel()`.

---

## Files NOT changed (important)

| Path | Reason not changed |
|------|-------------------|
| All Go source under `internal/` | Engine skin-not-fork policy |
| `main.go` | Same |
| `frontend/public/openapi.json` | Auto-generated; re-run after Go build |
| `frontend/src/pages/api-docs/` | Swagger UI working as-is |
| Database schema (`x-ui.db`) | Unchanged — settings added via SQL INSERT, not schema change |
| `install.sh` (upstream) | Replaced by `shanutechx-install.sh`; keep upstream for reference |
| Go package names | Never changed |
| systemd binary name `x-ui` | Never changed |

---

## How to merge a new upstream release

1. `git fetch upstream && git diff upstream/main...HEAD -- frontend/src/hooks/useTheme.tsx` — this is always the most likely conflict.
2. For each file in the **Changes by file** section above, apply the listed SHANUTECHX overrides on top of the upstream version.
3. For files in the **Not changed** section, take upstream directly.
4. Rebuild frontend: `cd frontend && npm ci && npm run build`.
5. Run `shanutechx-install.sh` in update mode on a staging VPS to verify.
