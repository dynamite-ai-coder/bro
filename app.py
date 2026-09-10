import os

from flask import Flask, send_from_directory

NOVNC_DIR = os.environ.get('NOVNC_DIR', '/usr/share/novnc')

app = Flask(__name__)


@app.route('/health')
def health():
    return {'status': 'healthy'}, 200


@app.route('/')
def index():
    return send_from_directory(NOVNC_DIR, 'index.html')


@app.route('/vnc.html')
def vnc():
    return send_from_directory(NOVNC_DIR, 'vnc.html')


@app.route('/<path:path>')
def static_files(path):
    return send_from_directory(NOVNC_DIR, path)


if __name__ == '__main__':
    port = int(os.environ.get('INTERNAL_PORT', '5000'))
    print(f'Starting noVNC web server on 127.0.0.1:{port}')
    app.run(host='127.0.0.1', port=port, debug=False, threaded=True)
