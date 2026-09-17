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
                                |     '-- /websockify   --> websockify :6080 --> x11vnc :5900
                                |                                                  |
RDP client --> ngrok/bore TCP --+--> xrdp :3389 --> x11vnc :5900 ------------------+--> Xvfb :0 --> XFCE
```

All processes are supervised by `supervisord` (started by `/start.sh`), so every
component restarts automatically. nginx is the only process bound to `$PORT`.

## Credentials

| Item | Value |
|------|-------|
| RDP username | `admin` |
| RDP password | `VNC_PASSWORD` (default `Dupa1234@`) |
| OS user | `admin` (sudo), `desktopuser` (desktop session, no sudo) |
| noVNC password | same as `VNC_PASSWORD` |

The RDP login bridges to x11vnc in password mode, so the username is ignored and
the password is the VNC password. The RFB protocol only uses the first 8
characters of the password, so `Dupa1234@` is effectively `Dupa1234`.

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Public HTTP port. Render sets this automatically (usually `10000`); do not set it manually |
| `RESOLUTION` | `1280x800` | Virtual desktop size; `24`-bit depth is appended automatically |
| `VNC_PASSWORD` | `Dupa1234@` | Password for RDP and noVNC. Change it in Render |
| `INTERNAL_PORT` | `5000` | Internal waitress port behind nginx |
| `NGROK_AUTHTOKEN` | (empty) | ngrok agent authtoken. When set, the RDP tunnel uses ngrok; otherwise the public bore.pub relay is used |
| `RDP_TUNNEL_PORT` | `0` | Requested public port for the bore tunnel (`0` = random) |
| `BORE_SECRET` | (empty) | Optional shared secret for a self-hosted bore server |
| `TUNNEL_FILE` | `/run/rdp-tunnel.txt` | Where the tunnel script writes `host:port` for `GET /rdp` |

## HTTP endpoints

| Path | Purpose |
|------|---------|
| `/` | Landing page with the "Open Desktop in Browser" button and the RDP endpoint |
| `/vnc.html` | noVNC web desktop (WebSocket to `/websockify`) |
| `/websockify` | WebSocket proxy to x11vnc (used by noVNC) |
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
5. Set environment variables in the dashboard (or `render.yaml`):
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

8. Open the service URL and click **Open Desktop in Browser** (noVNC), or connect
   a native RDP client to the address returned by `/rdp`.

### ngrok authtoken

The tunnel script prefers ngrok when `NGROK_AUTHTOKEN` is set. Create an agent
authtoken at https://dashboard.ngrok.com/get-started/your-authtoken and add it as
an environment variable. If ngrok fails, the container automatically falls back
to the public bore.pub relay.

## Local development

```bash
docker build -t bro .
docker run --rm -p 8080:8080 -e PORT=8080 -e VNC_PASSWORD=Dupa1234@ bro
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

- **Only HTTP/HTTPS is public on Render.** The browser desktop works directly;
  native RDP needs the ngrok/bore tunnel. Tunnel addresses change on every
  container start.
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
- The `admin` account has sudo inside the container. Treat the desktop as a
  shared secret.
- Rotate any API tokens that were shared in chat, logs or commits.

## Troubleshooting

- **Build fails**: check the Render build log; Chrome needs the packages in the
  Dockerfile, Tor Browser is downloaded from dist.torproject.org.
- **Health check fails**: `supervisorctl status` inside the container; nginx must
  listen on `$PORT`, waitress on `127.0.0.1:5000`.
- **Blank noVNC screen**: wait 5-10 s for XFCE, then reload; check
  `/var/log/x11vnc.log` and the nginx access log.
- **No RDP endpoint**: check the `tunnel` program logs; ngrok needs a valid
  `NGROK_AUTHTOKEN`, bore.pub needs outbound TCP 7835.
- **Log noise**: Render probes every listening port on localhost; x11vnc logs go
  to `/var/log/x11vnc.log` to keep the log stream readable.

## License

MIT
