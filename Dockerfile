FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV RESOLUTION=1280x800

RUN apt-get update && apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xorg \
    x11vnc \
    xvfb \
    novnc \
    websockify \
    supervisor \
    python3 \
    python3-pip \
    python3-venv \
    curl \
    wget \
    unzip \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb \
    && apt-get update \
    && apt-get install -y /tmp/chrome.deb \
    && rm /tmp/chrome.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash desktopuser \
    && echo "desktopuser:desktopuser" | chpasswd

RUN mkdir -p /home/desktopuser/.config \
    && mkdir -p /home/desktopuser/Desktop \
    && mkdir -p /home/desktopuser/.vnc \
    && chown -R desktopuser:desktopuser /home/desktopuser

RUN pip3 install --break-system-packages selenium flask

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh /start.sh
COPY app.py /app.py
COPY selenium_example.py /home/desktopuser/selenium_example.py
COPY novnc-index.html /usr/share/novnc/index.html

RUN chmod +x /start.sh \
    && chmod +x /usr/share/novnc/utils/novnc_proxy \
    && chown desktopuser:desktopuser /home/desktopuser/selenium_example.py

RUN mkdir -p /home/desktopuser/.config/xfce4/xfconf/xfce-perchannel-xml \
    && cat > /home/desktopuser/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml << 'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="custom" type="empty"/>
</channel>
XML

RUN mkdir -p /home/desktopuser/.config/autostart \
    && cat > /home/desktopuser/.config/autostart/chrome.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=Google Chrome
Exec=google-chrome --no-sandbox --disable-gpu --start-maximized
Hidden=false
DESKTOP

RUN chown -R desktopuser:desktopuser /home/desktopuser/.config

ENV DISPLAY=:0
ENV LANG=en_US.UTF-8

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8080}/health || exit 1

ENTRYPOINT ["/start.sh"]
