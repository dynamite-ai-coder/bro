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
    procps \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    supervisor \
    unzip \
    wget \
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

COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm -f /tmp/requirements.txt

COPY config/xrdp.ini /etc/xrdp/xrdp.ini
COPY scripts/ /usr/local/bin/

RUN chmod +x /usr/local/bin/start-xrdp.sh
