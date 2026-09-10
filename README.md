# Remote Desktop - Ubuntu XFCE with Chrome & Selenium

A browser-accessible Ubuntu 24.04 desktop environment with XFCE, Google Chrome, Selenium, and noVNC. Deploy to Render as a Docker Web Service.

## Features

- Full Ubuntu 24.04 XFCE desktop
- Google Chrome browser
- Selenium WebDriver support
- noVNC web-based desktop access
- Health check endpoint
- Render-compatible configuration

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Web server port (Render sets this automatically) |
| `RESOLUTION` | `1280x800` | Desktop resolution |
| `VNC_PASSWORD` | (empty) | Optional VNC password |

## Local Development

### Run with Docker

```bash
docker build -t remote-desktop .
docker run -p 8080:8080 -e PORT=8080 remote-desktop
```

### Access the Desktop

Open your browser and go to `http://localhost:8080`

### Run Selenium Example

```bash
docker exec -it <container_id> python3 /home/desktopuser/selenium_example.py
```

## Deploy to Render

1. Create a GitHub repository and push this code
2. Log in to [Render](https://dashboard.render.com)
3. Click "New" → "Web Service"
4. Connect your GitHub repository
5. Render will auto-detect the `render.yaml` configuration
6. Click "Create Web Service"

The service will be available at your Render URL (e.g., `https://bro.onrender.com`)

### Render Environment Variables

Set these in the Render dashboard:

- `PORT` - Automatically set by Render
- `RESOLUTION` - Optional, defaults to `1280x800`
- `VNC_PASSWORD` - Optional, for VNC authentication

## Troubleshooting

### Chrome Issues
- Ensure `--no-sandbox` flag is set (required in Docker)
- Check Chrome logs: `docker logs <container_id>`

### XFCE/Xvfb Issues
- Verify Xvfb is running: `ps aux | grep Xvfb`
- Check display: `echo $DISPLAY`

### VNC/WebSocket Issues
- Ensure noVNC is accessible on the correct port
- Check websockify logs for connection issues

### Memory Issues
- Use Render's paid plans for more RAM
- Close unnecessary applications in the desktop

## Architecture

```
Browser → Port 8080 → Flask (app.py)
                    → noVNC/websockify → x11vnc → Xvfb → XFCE
```

## License

MIT
