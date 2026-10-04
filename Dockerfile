FROM lscr.io/linuxserver/code-server:latest

# NodeSource v20 Repository hinzufügen & Systempakete installieren
RUN apt-get update && apt-get install -y curl ca-certificates gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y \
    nodejs \
    openssh-server \
    pandoc \
    graphviz \
    plantuml \
    git \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Globales vsce für Extension-Builds installieren
RUN npm install -g @vscode/vsce

# Decker installieren: Nimmt das neueste Asset aus allen Releases (inkl. Pre-Releases)
RUN DECKER_URL=$(curl -s https://api.github.com/repos/decker-edu/decker/releases | grep "browser_download_url" | grep -i "linux" | head -n 1 | cut -d '"' -f 4) \
    && wget -O /tmp/decker.tar.gz "$DECKER_URL" \
    && tar -xzf /tmp/decker.tar.gz -C /usr/local/bin \
    && chmod +x /usr/local/bin/decker \
    && rm /tmp/decker.tar.gz

# VSCode Extension decker-edu/vscode-decker-init aus Quellcode bauen und installieren
RUN git clone https://github.com/decker-edu/vscode-decker-init.git /tmp/vscode-decker-init \
    && cd /tmp/vscode-decker-init \
    && npm install \
    && vsce package --no-dependencies || vsce package \
    && code-server --install-extension *.vsix \
    && rm -rf /tmp/vscode-decker-init

# CustomInit-Skript für dynamische Paketinstallation per ENV (EXTRA_APT_PACKAGES)
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
