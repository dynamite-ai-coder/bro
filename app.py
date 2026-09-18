import os

from flask import Flask, Response, request, send_from_directory

NOVNC_DIR = os.environ.get('NOVNC_DIR', '/usr/share/novnc')
TUNNEL_FILE = os.environ.get('TUNNEL_FILE', '/run/rdp-tunnel.txt')
RDP_WS_PATH = os.environ.get('RDP_WS_PATH', 'rdpws')

app = Flask(__name__)

INDEX_HTML = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Remote Desktop</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; background: #1a1a2e; color: #fff; }
        .container { max-width: 800px; margin: 50px auto; padding: 20px; text-align: center; }
        h1 { margin-bottom: 20px; color: #e94560; }
        .btn { display: inline-block; padding: 15px 30px; background: #e94560; color: #fff;
               text-decoration: none; border-radius: 5px; font-size: 18px; margin: 10px; }
        .btn:hover { background: #c73e54; }
        .info { margin-top: 30px; padding: 20px; background: #16213e; border-radius: 5px;
                text-align: left; }
        .info h2 { font-size: 16px; color: #e94560; margin-bottom: 10px; }
        .info p, .info li { font-size: 14px; line-height: 1.6; }
        .info ul { margin-left: 20px; }
        .endpoint { font-family: monospace; font-size: 15px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Remote Desktop Environment</h1>
        <p>Ubuntu XFCE desktop with Tor Browser, Chrome and Selenium</p>
        <a href="/vnc.html" class="btn">Open Desktop in Browser</a>
        <div class="info">
            <h2>Native RDP client</h2>
            <p>Endpoint: <span class="endpoint" id="rdp-endpoint">checking&hellip;</span></p>
            <p>Username: <strong>admin</strong> &middot; Password: from <code>VNC_PASSWORD</code></p>
        </div>
        <div class="info">
            <h2>Stable native RDP over WebSocket</h2>
            <p>This Render URL never changes. Run <code>websocat</code> on your PC
               and connect your RDP client to <code>127.0.0.1:3389</code>:</p>
            <p class="endpoint" id="rdp-client">loading&hellip;</p>
        </div>
        <div class="info">
            <h2>Includes</h2>
            <ul>
                <li>XFCE desktop over noVNC (browser) and RDP (native client)</li>
                <li>Tor Browser and Google Chrome on the desktop</li>
                <li>Selenium WebDriver example script</li>
                <li>Persistent user files when a Render disk is attached at /data</li>
            </ul>
        </div>
    </div>
    <script>
        fetch('/rdp')
            .then(function (r) { return r.json(); })
            .then(function (d) {
                document.getElementById('rdp-endpoint').textContent =
                    d.rdp_endpoint || 'tunnel starting, refresh in a moment';
                document.getElementById('rdp-client').textContent =
                    d.rdp_client_command || 'not available';
            })
            .catch(function () {
                document.getElementById('rdp-endpoint').textContent = 'not available';
                document.getElementById('rdp-client').textContent = 'not available';
            });
    </script>
</body>
</html>
"""


def tunnel_address():
    try:
        with open(TUNNEL_FILE, encoding='utf-8') as fh:
            return fh.read().strip() or None
    except OSError:
        return None


@app.route('/health')
def health():
    return {'status': 'healthy'}, 200


@app.route('/version')
def version():
    return {
        'commit': os.environ.get('RENDER_GIT_COMMIT', 'unknown'),
        'branch': os.environ.get('RENDER_GIT_BRANCH', 'unknown'),
        'service': os.environ.get('RENDER_SERVICE_NAME', 'unknown'),
    }, 200


@app.route('/rdp')
def rdp():
    address = tunnel_address()
    host, _, port = (address or '').rpartition(':')
    scheme = request.headers.get('X-Forwarded-Proto', request.scheme)
    host = request.headers.get('X-Forwarded-Host', request.host)
    ws_base = ('wss://' if scheme == 'https' else 'ws://') + host
    ws_endpoint = f'{ws_base}/{RDP_WS_PATH}'
    return {
        'rdp_endpoint': address,
        'host': host or None,
        'port': int(port) if port.isdigit() else None,
        'status': 'ready' if address else 'starting',
        'rdp_ws_endpoint': ws_endpoint,
        'rdp_ws_path': RDP_WS_PATH,
        'rdp_client_command': f'websocat -b tcp-l:127.0.0.1:3389 {ws_endpoint}',
    }, 200


@app.route('/')
def index():
    return Response(INDEX_HTML, mimetype='text/html')


@app.route('/vnc.html')
def vnc():
    return send_from_directory(NOVNC_DIR, 'vnc.html')


@app.route('/<path:path>')
def static_files(path):
    return send_from_directory(NOVNC_DIR, path)


if __name__ == '__main__':
    port = int(os.environ.get('INTERNAL_PORT', '5000'))
    print(f'Starting web server on http://127.0.0.1:{port}')
    app.run(host='127.0.0.1', port=port, debug=False, threaded=True)
