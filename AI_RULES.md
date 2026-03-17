# AI_RULES.md

Guidelines for AI coding assistants working in this repository.

## Tech Stack

- **Runtime**: Node.js ≥ 24, ES Modules (`"type": "module"` in `package.json`). No build step — source runs directly with `node src/server.js`.
- **Backend framework**: [Express 5](https://expressjs.com/) (`express@^5`) for the HTTP server and REST API routes under `/setup/api/*`.
- **Reverse proxy**: [`http-proxy`](https://github.com/http-party/node-http-proxy) forwards all non-setup traffic (HTTP + WebSocket) to the internal OpenClaw gateway on `localhost:18789`.
- **WebSocket server**: [`ws`](https://github.com/websockets/ws) (`WebSocketServer`) handles the `/tui/ws` endpoint for the browser-based terminal.
- **Pseudo-terminal**: [`node-pty`](https://github.com/microsoft/node-pty) spawns an interactive PTY process (`openclaw tui`) for the Web TUI feature.
- **Frontend (setup wizard)**: Vanilla HTML/CSS/JS with [Alpine.js](https://alpinejs.dev/) (loaded from CDN) for reactivity. No bundler, no framework, no build step.
- **Styling**: Plain CSS in `src/public/styles.css`. No Tailwind, no CSS-in-JS, no preprocessors.
- **Persistence**: Filesystem only — config and state live in a Railway Volume mounted at `/data`. No database.
- **Deployment target**: [Railway](https://railway.app/) via Docker (`Dockerfile`). The app is a single-container wrapper around the `openclaw` CLI installed globally inside the image.

## Library Usage Rules

### HTTP & Routing
- Use **Express** for all server-side routing. Do not introduce Fastify, Koa, Hono, or any other HTTP framework.
- Keep all routes in `src/server.js`. Do not split routes into separate files unless the file grows unmanageable (>1000 lines of route logic).

### Proxying
- Use **`http-proxy`** for all reverse-proxy and WebSocket-proxy needs. Do not use `http-proxy-middleware` or manual `http.request` tunnelling.
- Always inject the `Authorization: Bearer <token>` header via `proxy.on("proxyReq")` and `proxy.on("proxyReqWs")` event handlers — **never** by mutating `req.headers` directly, as that does not reliably propagate to WebSocket upgrades.

### WebSockets
- Use **`ws`** (`WebSocketServer`) for any server-side WebSocket handling. Do not use `socket.io`.
- Attach WebSocket servers to the existing `http.Server` via `server.on("upgrade", ...)` — do not create a second HTTP server.

### Terminal / PTY
- Use **`node-pty`** for spawning interactive terminal processes. Do not use `child_process.spawn` with raw stdio for interactive sessions.

### Frontend
- The setup wizard (`src/public/`) is **vanilla JS + Alpine.js**. Do not introduce React, Vue, Svelte, or any npm-based frontend framework.
- Load Alpine.js from the CDN (`cdn.jsdelivr.net`). Do not bundle it.
- Write styles in `src/public/styles.css`. Do not use Tailwind, SCSS, or CSS Modules.
- Do not add a frontend build step (no Vite, Webpack, esbuild, etc.).

### Child Processes
- Use `child_process.spawn` (not `exec` or `execFile`) for running `openclaw` CLI commands to avoid shell-injection risks and to support streaming output.
- Use the `runCmd(cmd, args, opts)` helper for one-shot commands that capture output.
- Use `node-pty` only for interactive sessions that require a real TTY.

### Cryptography & Security
- Use Node's built-in **`crypto`** module for all hashing and token generation. Do not add `bcrypt`, `argon2`, or other third-party crypto packages.
- Always compare passwords with `crypto.timingSafeEqual` to prevent timing attacks.
- Never log or expose `SETUP_PASSWORD`, `OPENCLAW_GATEWAY_TOKEN`, or any API keys. Redact them in log output.

### Configuration & State
- All persistent state goes to the filesystem under `STATE_DIR` (default `/data/.openclaw`). Do not introduce a database (SQLite, Redis, Postgres, etc.).
- Read environment variables at startup; do not re-read them on every request.

### Logging
- Use the `log.info / log.warn / log.error` helpers (which write to the ring buffer, SSE clients, and the log file). Do not use `console.log` directly in new code.

### Dependencies
- Keep the dependency footprint minimal. The only runtime dependencies are `express`, `http-proxy`, `node-pty`, and `ws`. Do not add new npm packages without a strong reason.
- Do not add TypeScript, ESLint, Prettier, or test frameworks — the project intentionally has no toolchain overhead.
