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
    file \
    && rm -rf /var/lib/apt/lists/*

# Globales vsce für Extension-Builds installieren
RUN npm install -g @vscode/vsce

# PATH um den Pfad von code-server erweitern
ENV PATH="/app/code-server/bin:/usr/lib/code-server/bin:${PATH}"

# Decker installieren: Neuestes Linux-Asset (zip oder tar.gz) dynamisch ermitteln & entpacken
RUN DECKER_URL=$(curl -s https://api.github.com/repos/decker-edu/decker/releases | grep "browser_download_url" | grep -i "linux" | head -n 1 | cut -d '"' -f 4) \
    && echo "Downloading Decker from: $DECKER_URL" \
    && wget -O /tmp/decker_asset "$DECKER_URL" \
    && if file /tmp/decker_asset | grep -q 'Zip archive'; then \
           unzip /tmp/decker_asset -d /tmp/decker_out && \
           find /tmp/decker_out -type f -name "decker*" -exec mv {} /usr/local/bin/decker \; ; \
       elif file /tmp/decker_asset | grep -q 'gzip compressed'; then \
           tar -xzf /tmp/decker_asset -C /usr/local/bin ; \
       else \
           mv /tmp/decker_asset /usr/local/bin/decker ; \
       fi \
    && chmod +x /usr/local/bin/decker \
    && rm -rf /tmp/decker_asset /tmp/decker_out

# VSCode Extension decker-edu/vscode-decker-init aus Quellcode bauen und VSIX ablegen
RUN git clone https://github.com/decker-edu/vscode-decker-init.git /tmp/vscode-decker-init \
    && cd /tmp/vscode-decker-init \
    && npm install \
    && vsce package --no-dependencies || vsce package \
    && mkdir -p /var/default-extensions \
    && mv *.vsix /var/default-extensions/decker-init.vsix \
    && rm -rf /tmp/vscode-decker-init

# CustomInit-Skript für dynamische Paketinstallation per ENV (EXTRA_APT_PACKAGES) und VSIX Installation beim ersten Start
RUN mkdir -p /custom-cont-init.d/ && \
    echo '#!/bin/bash\n\
if [ -n "$EXTRA_APT_PACKAGES" ]; then\n\
    echo "Installing extra packages: $EXTRA_APT_PACKAGES"\n\
    apt-get update && apt-get install -y $EXTRA_APT_PACKAGES && rm -rf /var/lib/apt/lists/*\n\
fi\n\
if [ -f /var/default-extensions/decker-init.vsix ]; then\n\
    echo "Installing decker-init extension..."\n\
    /app/code-server/bin/code-server --install-extension /var/default-extensions/decker-init.vsix || true\n\
fi' > /custom-cont-init.d/10-init-setup.sh && \
    chmod +x /custom-cont-init.d/10-init-setup.sh

# SSH Konfiguration anpassen
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# CustomInit-Skript zum automatischen Starten des SSH-Dienstes
RUN echo '#!/bin/bash\n\
/usr/sbin/sshd' > /custom-cont-init.d/20-start-sshd.sh && \
    chmod +x /custom-cont-init.d/20-start-sshd.sh

EXPOSE 8443 22
