# bro - Ubuntu XFCE Remote Desktop on Render

Docker-based Ubuntu 24.04 desktop with XFCE, Tor Browser, Google Chrome, Selenium
and two ways to reach it:

- **noVNC in the browser** through the Render HTTPS URL (no client needed)
- **native RDP** through an ngrok (or bore.pub) TCP tunnel, because Render only
  publishes HTTP/HTTPS ports for web services

Deployed as a Docker web service on Render:

- Service: `novnc` -> https://bro-56z7.onrender.com

## Architecture

```
Browser --HTTPS/WSS--> Render --+--> nginx :$PORT
                                |     |-- /            --> waitress/Flask :5000  (landing, /health, /rdp)
                                |     |-- /vnc.html     --> waitress/Flask :5000  (noVNC app + static files)
                                |     |-- /websockify   --> websockify :6080 --> x11vnc :5900
                                |     '-- /<RDP_WS_PATH> --> rdpws bridge :6081 --> xrdp :3389
                                |                                                  |
RDP client --> ngrok/pinggy/bore TCP --+--> xrdp :3389 --> x11vnc :5900 ----------+--> Xvfb :0 --> XFCE
```

The `/<RDP_WS_PATH>` route is a **stable** native-RDP path: it never changes
because it goes through the Render HTTPS URL, which is fixed. Tunnels
(ngrok/pinggy/bore) are only a fallback for clients that cannot run a local
WebSocket bridge.

All processes are supervised by `supervisord` (started by `/start.sh`), so every
component restarts automatically. nginx is the only process bound to `$PORT`.

## Credentials

| Item | Value |
|------|-------|
| RDP username | `admin` |
| RDP password | `VNC_PASSWORD` (Render env var, no value in the repo) |
| OS user | desktop session runs as `root`; `admin` and `desktopuser` exist for console use |
| noVNC password | same as `VNC_PASSWORD` |

The XFCE session runs as `root`, so after logging in (browser or RDP) every
terminal already has full admin rights. Render starts containers with the
`no-new-privileges` flag, which stops `sudo` from elevating; running the session
as root is the only way to get admin rights on Render. Tor Browser refuses to
run as root, so its launcher drops back to `desktopuser` with `runuser`.

The RDP login bridges to x11vnc in password mode, so the username is ignored and
the password is the VNC password. The RFB protocol only uses the first 8
characters of the password.

The password is never stored in the repository: `render.yaml` declares
`VNC_PASSWORD` with `sync: false`, so Render asks for it and keeps it as a
secret environment variable. The container sets the OS account passwords and the
x11vnc password from that variable at startup.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Public HTTP port. Render sets this automatically (usually `10000`); do not set it manually |
| `RESOLUTION` | `1280x800` | Virtual desktop size; `24`-bit depth is appended automatically |
| `VNC_PASSWORD` | (required) | Password for RDP and noVNC. Set it in the Render dashboard; it is stored only on Render. The RFB protocol only uses the first 8 characters; avoid `:` in the value |
| `INTERNAL_PORT` | `5000` | Internal waitress port behind nginx |
| `NGROK_AUTHTOKEN` | (empty) | ngrok agent authtoken. ngrok TCP endpoints require a verified payment method; on a free account the script automatically falls back to pinggy |
| `RDP_TUNNEL_PORT` | `0` | Requested public port for the bore tunnel (`0` = random) |
| `BORE_SECRET` | (empty) | Optional shared secret for a self-hosted bore server |
| `TUNNEL_FILE` | `/run/rdp-tunnel.txt` | Where the tunnel script writes `host:port` for `GET /rdp` |
| `RDP_WS_PATH` | `rdpws` | URL path of the stable RDP WebSocket bridge. Set a random value to hide the endpoint |

## HTTP endpoints

| Path | Purpose |
|------|---------|
| `/` | Landing page with the "Open Desktop in Browser" button and the RDP endpoint |
| `/vnc.html` | noVNC web desktop (WebSocket to `/websockify`) |
| `/websockify` | WebSocket proxy to x11vnc (used by noVNC) |
| `/<RDP_WS_PATH>` | Stable WebSocket-to-RDP bridge (xrdp 3389), used by the `websocat` client |
| `/health` | Health check used by Render |
| `/version` | Deployed commit/branch/service from Render env vars |
| `/rdp` | JSON with the current public RDP endpoint and status |

## Deploy to Render (step by step)

1. Push this repository to GitHub (branch `main`). The service `novnc` already
   exists and auto-deploys from that branch, so a push is enough.
2. To create the service from scratch: in the Render dashboard click
   **New -> Web Service**, connect the repository and choose **Docker**.
3. Render reads `render.yaml`. Keep the region/plan you need. A desktop with a
   browser needs **at least 2 GB RAM** (the current service runs on `4c-8g`).
4. Add a persistent disk (optional but recommended):
   - Name: `desktop-data`, mount path: `/data`, size: 1 GB or more
   - Files in `Desktop`, `Documents`, `Downloads` and the Chrome profile survive
     restarts and deploys. Without the disk everything is ephemeral.
5. Set environment variables in the dashboard (**required**; they are stored on
   Render, not in the repo):
   - `VNC_PASSWORD` = your RDP/noVNC password
   - `NGROK_AUTHTOKEN` = ngrok agent token (optional; without it bore.pub is used)
6. Click **Create Web Service** and wait for the first build (~5-10 minutes).
7. Verify:

```bash
curl -i https://bro-56z7.onrender.com/health
# {"status":"healthy"}

curl -s https://bro-56z7.onrender.com/version
# {"commit":"...","branch":"main","service":"novnc"}

curl -s https://bro-56z7.onrender.com/rdp
# {"rdp_endpoint":"2.tcp.eu.ngrok.io:12345", ...}
```

8. Open the service URL and click **Open Desktop in Browser** (noVNC), or use
   the stable native RDP path described below.

### Stable native RDP over WebSocket (free, no more changing ports)

Native RDP needs raw TCP, which Render (and the free ngrok plan) does not expose.
Instead of chasing a rotating tunnel address, bridge the fixed Render URL to a
local port with a tiny WebSocket client:

1. Download `websocat` for your OS from
   https://github.com/vi/websocat/releases (single binary, no install).
2. Run it on the machine where your RDP client is:

```bash
websocat -b tcp-l:127.0.0.1:3389 wss://bro-56z7.onrender.com/rdpws
```

3. Connect any RDP client (mstsc, Remmina, FreeRDP) to:

```
127.0.0.1:3389
```

The URL is the Render service URL and the local port is fixed, so this endpoint
never changes and does not expire. Keep `websocat` running while you use the
desktop. Username `admin`, password `VNC_PASSWORD`.

To hide the bridge behind an unguessable path, set `RDP_WS_PATH` (for example a
random string) in the Render dashboard and use
`wss://bro-56z7.onrender.com/<RDP_WS_PATH>` in the client command. `GET /rdp`
returns the exact `rdp_client_command` for the current deployment.

### ngrok authtoken and tunnel fallbacks

The tunnel script tries providers in order:

1. **ngrok** when `NGROK_AUTHTOKEN` is set. TCP endpoints on a free ngrok
   account are rejected (`ERR_NGROK_8013`) until a payment method is verified at
   https://dashboard.ngrok.com/settings#id-verification.
2. **pinggy** (`ssh -R` TCP tunnel). Free sessions last 60 minutes; the
   supervisor restarts the script automatically, so the endpoint refreshes
   itself with a new address.
3. **bore.pub** public relay as the last resort.

The current address is always available at `GET /rdp` and on the landing page.

## Local development

```bash
docker build -t bro .
docker run --rm -p 8080:8080 -e PORT=8080 -e VNC_PASSWORD=change-me bro
```

Open http://localhost:8080 for the landing page and http://localhost:8080/vnc.html
for the desktop. Native RDP is on port 3389 inside the container; publish it with
`-p 3389:3389` if you want to test an RDP client locally.

Run the Selenium example inside the container:

```bash
docker exec -it <container_id> /opt/venv/bin/python3 /home/desktopuser/selenium_example.py
```

Set `SELENIUM_HEADLESS=1` to run Chrome without a visible window.

## Limitations

- **Only HTTP/HTTPS is public on Render.** The browser desktop works directly, and
  the stable `/<RDP_WS_PATH>` WebSocket bridge covers native RDP clients through
  the same fixed URL. The ngrok/pinggy/bore tunnel remains as a fallback for
  clients that cannot run `websocat`; tunnel addresses change on every container
  start, and pinggy sessions expire after 60 minutes (the endpoint
  refreshes automatically).
- **Free/low plans sleep** after inactivity, which drops RDP sessions and the
  tunnel. Use a paid instance type for reliable access.
- **RAM**: XFCE + Chrome + Tor Browser needs 1-2 GB minimum. On smaller instances
  close unused applications inside the desktop.
- **RFB truncates passwords to 8 characters** (see Credentials).
- **Tor Browser state is not persisted** (its install directory is inside the
  image). Bookmarks/dotfiles outside the persisted folders are lost on redeploy.
- **One shared desktop**: native RDP and noVNC viewers see and control the same
  XFCE session.
- Chrome runs with `--no-sandbox` because containers cannot use the Chrome
  sandbox; Tor Browser runs with `MOZ_DISABLE_CONTENT_SANDBOX=1`. Do not reuse
  this image for untrusted browsing.
- Render terminates TLS; inside the container traffic (including the VNC
  password over WebSocket) is plain.

## Security

- Always set `VNC_PASSWORD`. Without it anyone who finds the URL controls the
  desktop.
- The public TLS endpoint, the tunnel endpoint and the password are the only
  protection. Rotate the password if the URL leaks.
- The XFCE session, the desktop apps and every terminal run as root. `sudo` is
  blocked by Render's `no-new-privileges` flag; admin commands work directly.
  Treat the desktop as a shared secret.
- The password is only stored as a Render environment variable and inside the
  running container; it is never committed to the repository.
- Rotate any API tokens that were shared in chat, logs or commits.

## Troubleshooting

- **Build fails**: check the Render build log; Chrome needs the packages in the
  Dockerfile, Tor Browser is downloaded from dist.torproject.org.
- **Health check fails**: `supervisorctl status` inside the container; nginx must
  listen on `$PORT`, waitress on `127.0.0.1:5000`.
- **Blank noVNC screen**: wait 5-10 s for XFCE, then reload; check
  `/var/log/x11vnc.log` and the nginx access log.
- **Black terminal window, no prompt, typing does nothing**: the desktop used
  to launch `zutty`, which needs OpenGL and stays black on the Xvfb display.
  The image now installs `xfce4-terminal` (default, `Ctrl+Alt+T`) plus `xterm`
  and removes zutty; redeploy to pick up the change.
- **`sudo: The "no new privileges" flag is set`**: expected on Render. The
  desktop session already runs as root, so admin commands work without `sudo`.
- **"Untrusted application launcher" when double-clicking a desktop icon**:
  standard XFCE confirmation for `.desktop` launchers it has not seen before.
  Click **Launch Anyway** (or **Mark Executable**) once. The same apps start
  from the Applications menu without any prompt.
- **No RDP endpoint**: check the `tunnel` program logs; ngrok needs a valid
  `NGROK_AUTHTOKEN`, bore.pub needs outbound TCP 7835.
- **Log noise**: Render probes every listening port on localhost; x11vnc logs go
  to `/var/log/x11vnc.log` to keep the log stream readable.

## License

MIT
