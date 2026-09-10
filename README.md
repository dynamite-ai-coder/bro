# Remote Desktop - Ubuntu XFCE with Chrome & Selenium

A browser-accessible Ubuntu 24.04 desktop environment with XFCE, Google Chrome, Selenium and noVNC. Ships as a single Docker image and deploys to Render as a Docker web service.

Service: https://bro-56z7.onrender.com

## Features

- Full Ubuntu 24.04 XFCE desktop
- Google Chrome browser (auto-starts in the session)
- Selenium WebDriver support (driver resolved automatically by Selenium Manager)
- noVNC web-based desktop access over WebSocket
- Optional VNC password authentication
- Supervisor-managed processes with automatic restarts
- Health check endpoint at `/health`
- Render blueprint (`render.yaml`) with auto-deploy

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Public HTTP port (Render sets this to `10000` automatically) |
| `RESOLUTION` | `1280x800` | Virtual desktop resolution |
| `VNC_PASSWORD` | (empty) | Optional VNC password. Empty = no auth |
| `INTERNAL_PORT` | `5000` | Internal Flask port (do not change unless you also change nginx) |

## Local Development

### Run with Docker

```bash
docker build -t remote-desktop .
docker run --rm -p 8080:8080 -e PORT=8080 -e VNC_PASSWORD=secret remote-desktop
```

### Access the Desktop

Open `http://localhost:8080` and click **Open Desktop** (`/vnc.html`).

### Run the Selenium Example

```bash
docker exec -it <container_id> /opt/venv/bin/python3 /home/desktopuser/selenium_example.py
```

Set `SELENIUM_HEADLESS=1` to run Chrome without showing a window:

```bash
docker exec -it -e SELENIUM_HEADLESS=1 <container_id> /opt/venv/bin/python3 /home/desktopuser/selenium_example.py
```

## Deploy to Render

The service `bro` already exists on Render and auto-deploys from the `main` branch of this repository. Push a commit to trigger a build:

```bash
git push origin main
```

To create the service from scratch:

1. Push this repository to GitHub
2. In the Render dashboard click **New → Web Service**
3. Connect the repository, Render detects `render.yaml`
4. Set `VNC_PASSWORD` if desired and click **Create Web Service**

`PORT` is provided by Render; do not set it manually.

### Verify the deployment

```bash
curl -i https://bro-56z7.onrender.com/health
# HTTP/1.1 200 OK
# {"status":"healthy"}
```

## Architecture

```
Browser ──HTTPS/WSS──▶ Render ──▶ nginx :$PORT
                                    ├── /            ──▶ waitress/Flask :5000 (noVNC static + /health)
                                    └── /websockify  ──▶ websockify :6080 ──▶ x11vnc :5900 ──▶ Xvfb :0 ──▶ XFCE
```

All processes are managed by `supervisord`, which is started by `start.sh`.
nginx is the only process bound to the public `$PORT`.

## Security

- Set `VNC_PASSWORD` in Render. Without it, anyone with the URL controls the desktop.
- The desktop user (`desktopuser`) has no privileges beyond the container.
- Chrome runs with `--no-sandbox` because containers cannot use the Chrome sandbox; do not reuse this image for untrusted browsing.
- Rotate any API tokens you have shared in chat or logs.

## Troubleshooting

### Build fails

- Check the Render build log for the failing step.
- Chrome requires `wget`, `unzip` and the packages installed in the Dockerfile.

### Health check fails

- Confirm nginx started: logs should contain `nginx: listening on port ...`.
- Confirm Flask/websockify are up: `supervisorctl status` inside the container.
- The first boot takes ~30 s; the health check has a 60 s start period.

### Blank screen in noVNC

- Wait for XFCE to start (5-10 s after the container is healthy).
- Check `x11vnc` logs with `docker logs <container>`.
- Make sure `/websockify` reaches websockify; check the nginx access log.

### Out of memory

- XFCE plus Chrome needs at least 1-2 GB of RAM. Use a Render instance type with 2 GB or more.
- Close unused applications inside the desktop.

## License

MIT
