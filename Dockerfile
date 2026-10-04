FROM lscr.io/linuxserver/code-server:latest

# Systempaket-Abhängigkeiten installieren
RUN apt-get update && apt-get install -y \
    openssh-server \
    pandoc \
    graphviz \
    plantuml \
    curl \
    git \
    wget \
    unzip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Globales vsce für Extension-Builds installieren
RUN npm install -g @vscode/vsce

# Neuestes Decker-Release von GitHub herunterladen und installieren
RUN DECKER_URL=$(curl -s https://api.github.com/repos/decker-edu/decker/releases/latest | grep "browser_download_url.*linux-x86_64.tar.gz" | cut -d '"' -f 4) \
    && wget -O /tmp/decker.tar.gz "$DECKER_URL" \
    && tar -xzf /tmp/decker.tar.gz -C /usr/local/bin \
    && chmod +x /usr/local/bin/decker \
    && rm /tmp/decker.tar.gz

# VSCode Extension decker-edu/vscode-decker-init aus Quellcode bauen und installieren
RUN git clone https://github.com/decker-edu/vscode-decker-init.git /tmp/vscode-decker-init \
    && cd /tmp/vscode-decker-init \
    && npm install \
    && vsce package \
    && code-server --install-extension *.vsix \
    && rm -rf /tmp/vscode-decker-init

# CustomInit-Skript für dynamische Paketinstallation per ENV (EXTRA_APT_PACKAGES) erstellen
RUN mkdir -p /custom-cont-init.d/ && \
    echo '#!/bin/bash\n\
if [ -n "$EXTRA_APT_PACKAGES" ]; then\n\
    echo "Installing extra packages: $EXTRA_APT_PACKAGES"\n\
    apt-get update && apt-get install -y $EXTRA_APT_PACKAGES && rm -rf /var/lib/apt/lists/*\n\
fi' > /custom-cont-init.d/10-install-extra-pkgs.sh && \
    chmod +x /custom-cont-init.d/10-install-extra-pkgs.sh

# SSH Konfiguration anpassen
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# CustomInit-Skript zum automatischen Starten des SSH-Dienstes
RUN echo '#!/bin/bash\n\
/usr/sbin/sshd' > /custom-cont-init.d/20-start-sshd.sh && \
    chmod +x /custom-cont-init.d/20-start-sshd.sh

EXPOSE 8443 22
