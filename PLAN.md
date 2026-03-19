# Plan: Composio connect flow — success close window, connect in new window

## Findings

- **This repo (sparti-openclaw)** has no Composio integration. It is the OpenClaw Railway wrapper (setup wizard, gateway proxy, TUI). No `connect.composio.dev` / `platform.composio.dev` or Supabase connection flow exists here.
- **Success URL (Composio)**  
  Example:  
  `https://platform.composio.dev/link/lk_VImvoqPwaP29?status=success&connectedAccountId=ca_Prq3EhGdaCbv&appName=supabase`  
  This is on Composio’s domain. To “just close, no redirect” we need the **final redirect** to go to **our app**, then our page closes the window (e.g. `window.close()`).
- **Connect link (from bot or UI)**  
  Example:  
  `https://connect.composio.dev/link/lk_VImvoqPwaP29`  
  When the user clicks “Connect”, this must open in a **new window/tab** so the main app stays open and the popup can be closed after success.
- **No duplicate flows** in this repo; no existing callback or OAuth route to reuse.

## Desired behavior

1. **Connect**  
   - User clicks “Connect” (or bot sends one-click link).  
   - Connect link opens in a **new window** (not replace current tab).
2. **After success**  
   - Composio redirects to **our** callback URL (e.g. `https://our-app/integrations/composio/callback?status=success&connectedAccountId=...&appName=...`).  
   - Callback page: **no redirect**; show a short “Successfully connected” and **close the window** (so the popup disappears and the opener tab stays on the app).

## Plan

### 1. Callback URL and page (in the app that uses Composio)

- **Option A – Composio “redirect URL” points to our app**  
  - Add a route in the app that uses Composio (e.g. Clawdi.ai or this template if you add Composio later), e.g.:  
    - `GET /integrations/composio/callback` or  
    - `GET /api/integrations/composio/callback`
  - That route serves a minimal HTML page that:
    - Reads query params: `status`, `connectedAccountId`, `appName`.
    - If `status === 'success'`: show “Successfully connected” (and optionally notify opener via `postMessage` or poll), then call `window.close()`.
    - If not success: show “Connection failed” or “You can close this window.”
  - No HTTP redirect (no `Location` header); the page stays on the callback URL and closes the window from script.

- **Option B – Stay on Composio success URL**  
  - If we cannot set a custom redirect and must land on `platform.composio.dev/...?status=success&...`, then we **cannot** close the window from our code (it’s their page). In that case, the only option is to configure the link so that the **redirect URL** in Composio’s link config points to our callback (Option A). Confirm in Composio dashboard/link config that the “redirect URL” or “success URL” is set to our callback.

### 2. Open connect link in new window

- **In UI**  
  - “Connect” button/link must open the Composio link in a new window:
  - Either:  
    `<a href="https://connect.composio.dev/link/lk_XXX" target="_blank" rel="noopener">Connect</a>`
  - Or:  
    `window.open('https://connect.composio.dev/link/lk_XXX', '_blank', 'noopener')`
- **From bot**  
  - Send the one-click link as-is:  
    `https://connect.composio.dev/link/lk_VImvoqPwaP29`  
  - When the user opens it (e.g. in Telegram/Discord), it typically opens in a new tab/window by default; no extra change needed for “new window” on our side.

### 3. Backend (optional)

- If you need to persist `connectedAccountId` or run logic after success:
  - Callback page can `postMessage` to opener with `connectedAccountId` and `appName`.
  - Or callback route can be server-rendered: server reads query params, stores/updates integration state, then responds with the same minimal HTML that runs `window.close()`.

### 4. Where to implement

- **If the app with Composio is another repo (e.g. Clawdi.ai):**  
  Implement the callback route + callback page and “Connect” in new window in that repo. Use this plan as the spec.
- **If you add Composio to this repo later:**  
  - Add the callback route in `src/server.js` (e.g. `GET /integrations/composio/callback`) and serve a small HTML file from `src/public/` that does the success check and `window.close()`.
  - Any “Connect” link in `src/public/setup.html` (or future UI) must use `target="_blank"` for the Composio link.

## Docs to update

- **README.md**  
  - If Composio callback is added to this repo: add a short “Integrations (Composio)” section describing the connect flow (new window, callback closes window, no redirect).
- **CLAUDE.md**  
  - If you add Composio here: add a note under “Common Development Tasks” or “Quirks” about the callback URL and “success = close window, no redirect.”
- **TODO.md**  
  - Create if missing; add a task “Composio connect: callback page + new-window link” and mark done when implemented.

## Verification

- Click “Connect” → new window opens with Composio.
- Complete connection (e.g. Supabase) → redirect to our callback URL → page shows success and popup closes.
- Main tab/window never navigates away; no extra redirect after success.
