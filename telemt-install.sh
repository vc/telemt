#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

for tool in curl jq openssl tar; do
    if ! command -v "$tool" &> /dev/null; then
        echo "> Installing missing tools..."
        apt update
        apt install -y curl jq openssl tar
        break
    fi
done

INSTALL_DIR=/usr/local/bin
GITHUB_USER_REPO="telemt/telemt"
FIND_STR="telemt"
ARCH_PATTERN=$(uname -m)
TLS_DOMAIN=microsoft.com

echo "> Searching ${FIND_STR}/${ARCH_PATTERN} latest release on GitHub repo ${GITHUB_USER_REPO} ..."
RELEASE_URL=$(curl -Ls https://api.github.com/repos/${GITHUB_USER_REPO}/releases/latest \
    | jq -r ".assets[] | select(.name | contains(\"${FIND_STR}\") and contains(\"${ARCH_PATTERN}\") and contains(\".tar.gz\")).browser_download_url")
if [[ -z "${RELEASE_URL}" ]] || [[ "${RELEASE_URL}" == "null" ]]; then
    echo "> ERROR: no release URL found for ${GITHUB_USER_REPO} with filter '${FIND_STR}'."
    exit 1
else
    echo "> Release url: ${RELEASE_URL}. Downloading..."
fi

if ! curl -Ls "${RELEASE_URL}" | tar -xzf - -C "${INSTALL_DIR}"; then
    echo "> ERROR: Failed to download or extract the archive."
    exit 1
fi

if [ ! -f "${INSTALL_DIR}/telemt" ]; then
    echo "> ERROR: telemt binary not found after extraction."
    exit 1
fi

chown root:root ${INSTALL_DIR}/telemt
chmod 755 ${INSTALL_DIR}/telemt

cat << EOT > /etc/telemt.toml
# === General Settings ===
[general]
# ad_tag = "00000000000000000000000000000000"
use_middle_proxy = false

[general.modes]
classic = false
secure = false
tls = true

[server]
port = 443

[server.api]
enabled = true
# listen = "127.0.0.1:9091"
# whitelist = ["127.0.0.1/32"]
# read_only = true

# === Anti-Censorship & Masking ===
[censorship]
tls_domain = "$TLS_DOMAIN"

[access.users]
# format: "username" = "32_hex_chars_secret"
hello = "$(openssl rand -hex 16)"
$(for i in {1..16}; do echo "user$i = \"$(openssl rand --hex 16)\""; done)
EOT

useradd -d /opt/telemt -m -r -U telemt
chown -R telemt:telemt /etc/telemt

cat << EOT > /etc/systemd/system/telemt.service
[Unit]
Description=Telemt
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=telemt
Group=telemt
WorkingDirectory=/opt/telemt
ExecStart=/usr/local/bin/telemt /etc/telemt.toml
Restart=on-failure
LimitNOFILE=65536
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable telemt
systemctl start telemt

curl -s http://127.0.0.1:9091/v1/users | jq -r '.data[] | .username as $name | .links.tls[] | select(contains("::") | not) | "\($name): \(.)"'