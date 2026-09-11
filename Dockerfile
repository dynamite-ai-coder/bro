FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:0 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    RESOLUTION=1280x800

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    dbus-x11 \
    fonts-liberation \
    locales \
    net-tools \
    nginx \
    novnc \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    supervisor \
    unzip \
    wget \
    websockify \
    x11-utils \
    x11-xserver-utils \
    x11vnc \
    xdg-utils \
    xfce4 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb \
    && apt-get update \
    && apt-get install -y /tmp/google-chrome.deb \
    && rm -f /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

RUN useradd -m -s /bin/bash desktopuser \
    && echo "desktopuser:desktopuser" | chpasswd

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

RUN mkdir -p /home/desktopuser/.config/xfce4/xfconf/xfce-perchannel-xml \
    && mkdir -p /home/desktopuser/.config/autostart \
    && mkdir -p /home/desktopuser/Desktop

COPY config/xfce4-keyboard-shortcuts.xml /home/desktopuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
COPY config/google-chrome.desktop /home/desktopuser/.config/autostart/google-chrome.desktop
COPY config/gnome-keyring-hidden.desktop /home/desktopuser/.config/autostart/gnome-keyring-secrets.desktop
COPY config/gnome-keyring-hidden.desktop /home/desktopuser/.config/autostart/gnome-keyring-ssh.desktop
COPY config/gnome-keyring-hidden.desktop /home/desktopuser/.config/autostart/gnome-keyring-pkcs11.desktop

RUN cp /home/desktopuser/.config/autostart/google-chrome.desktop /home/desktopuser/Desktop/google-chrome.desktop \
    && chmod +x /home/desktopuser/Desktop/google-chrome.desktop \
    && chown -R desktopuser:desktopuser /home/desktopuser

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY app.py /app.py
COPY novnc-index.html /usr/share/novnc/index.html
COPY selenium_example.py /home/desktopuser/selenium_example.py
COPY scripts/ /usr/local/bin/
COPY start.sh /start.sh

RUN chmod +x /start.sh /usr/local/bin/start-x11vnc.sh /usr/local/bin/start-xfce.sh /usr/local/bin/start-nginx.sh \
    && chown desktopuser:desktopuser /home/desktopuser/selenium_example.py

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT:-8080}/health" || exit 1

ENTRYPOINT ["/start.sh"]
