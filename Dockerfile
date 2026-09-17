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
    iproute2 \
    libasound2t64 \
    libdbus-glib-1-2 \
    libxt6t64 \
    locales \
    net-tools \
    nginx \
    novnc \
    openssh-client \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
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
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends xrdp \
    && adduser xrdp ssl-cert \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -G sudo admin \
    && echo 'admin:Dupa1234@' | chpasswd

RUN useradd -m -s /bin/bash desktopuser \
    && echo 'desktopuser:desktopuser' | chpasswd

RUN mkdir -p /home/desktopuser/.config/xfce4/xfconf/xfce-perchannel-xml \
    && mkdir -p /home/desktopuser/.config/autostart \
    && mkdir -p /home/desktopuser/Desktop \
    && chown -R desktopuser:desktopuser /home/desktopuser

RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb \
    && apt-get update \
    && apt-get install -y /tmp/google-chrome.deb \
    && rm -f /tmp/google-chrome.deb \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -O /tmp/ngrok.tgz \
    && tar -xzf /tmp/ngrok.tgz -C /usr/local/bin ngrok \
    && chmod +x /usr/local/bin/ngrok \
    && rm -f /tmp/ngrok.tgz

ARG BORE_VERSION=0.6.0
RUN wget -q "https://github.com/ekzhang/bore/releases/download/v${BORE_VERSION}/bore-v${BORE_VERSION}-x86_64-unknown-linux-musl.tar.gz" -O /tmp/bore.tgz \
    && tar -xzf /tmp/bore.tgz -C /usr/local/bin bore \
    && chmod +x /usr/local/bin/bore \
    && rm -f /tmp/bore.tgz

ARG TOR_BROWSER_VERSION=15.0.23
RUN wget -q "https://dist.torproject.org/torbrowser/${TOR_BROWSER_VERSION}/tor-browser-linux-x86_64-${TOR_BROWSER_VERSION}.tar.xz" -O /tmp/tor-browser.tar.xz \
    && mkdir -p /home/desktopuser/tor-browser \
    && tar -xJf /tmp/tor-browser.tar.xz -C /home/desktopuser/tor-browser --strip-components=1 \
    && rm -f /tmp/tor-browser.tar.xz \
    && test -x /home/desktopuser/tor-browser/Browser/start-tor-browser \
    && chown -R desktopuser:desktopuser /home/desktopuser/tor-browser

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

COPY config/xfce4-keyboard-shortcuts.xml /home/desktopuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
COPY config/google-chrome.desktop /home/desktopuser/.config/autostart/google-chrome.desktop
COPY config/gnome-keyring-hidden.desktop /home/desktopuser/.config/autostart/gnome-keyring-secrets.desktop
COPY config/gnome-keyring-hidden.desktop /home/desktopuser/.config/autostart/gnome-keyring-ssh.desktop
COPY config/gnome-keyring-hidden.desktop /home/desktopuser/.config/autostart/gnome-keyring-pkcs11.desktop
COPY config/tor-browser.desktop /home/desktopuser/Desktop/tor-browser.desktop
COPY config/tor-browser.desktop /usr/share/applications/tor-browser.desktop

RUN cp /home/desktopuser/.config/autostart/google-chrome.desktop /home/desktopuser/Desktop/google-chrome.desktop \
    && chmod +x /home/desktopuser/Desktop/google-chrome.desktop /home/desktopuser/Desktop/tor-browser.desktop \
    && chown -R desktopuser:desktopuser /home/desktopuser

COPY selenium_example.py /home/desktopuser/selenium_example.py

COPY config/xrdp.ini /etc/xrdp/xrdp.ini
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY app.py /app.py
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/ /usr/local/bin/
COPY start.sh /start.sh

RUN chmod +x /start.sh /usr/local/bin/start-nginx.sh /usr/local/bin/start-web.sh \
        /usr/local/bin/start-x11vnc.sh /usr/local/bin/start-xfce.sh /usr/local/bin/start-xrdp.sh \
    && chown desktopuser:desktopuser /home/desktopuser/selenium_example.py

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS "http://localhost:${PORT:-8080}/health" || exit 1

ENTRYPOINT ["/start.sh"]
