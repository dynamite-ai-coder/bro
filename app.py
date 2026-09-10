import os
import signal
import sys
from flask import Flask, redirect, send_from_directory

app = Flask(__name__)

NOVNC_PORT = os.environ.get('PORT', '8080')

@app.route('/')
def index():
    return redirect('/vnc.html')

@app.route('/health')
def health():
    return {'status': 'healthy'}, 200

@app.route('/vnc.html')
def vnc():
    return send_from_directory('/usr/share/novnc', 'vnc.html')

@app.route('/<path:path>')
def static_files(path):
    return send_from_directory('/usr/share/novnc', path)

def signal_handler(sig, frame):
    print("Shutting down gracefully...")
    sys.exit(0)

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    print(f"Starting web server on port {port}")
    app.run(host='0.0.0.0', port=port, debug=False)
