#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Parse command line arguments
FORCE_UPDATE="false"
for arg in "$@"; do
    if [[ "${arg}" == "--force" ]]; then
        FORCE_UPDATE="true"
    fi
done

if [[ "${FORCE_UPDATE}" == "true" ]]; then
    echo "> Force update enabled. Skipping version checks."
fi

for tool in curl jq tar; do
    if ! command -v "$tool" &> /dev/null; then
        echo "> Installing missing tools..."
        apt update
        apt install -y curl jq openssl tar
        break
    fi
done

GITHUB_USER_REPO="telemt/telemt"
FIND_STR="telemt"
ARCH_PATTERN=$(uname -m)
INSTALL_DIR=/usr/local/bin

echo "> Searching latest release on GitHub..."
RELEASE_URL=$(curl -sL "https://api.github.com/repos/${GITHUB_USER_REPO}/releases/latest" \
    | jq -r ".assets | map(select(.name | contains(\"${FIND_STR}\") and contains(\"${ARCH_PATTERN}\") and contains(\".tar.gz\") and (contains(\".sha256\") | not)).browser_download_url) | first")
if [[ -z "${RELEASE_URL}" ]] || [[ "${RELEASE_URL}" == "null" ]]; then
    echo "> ERROR: no release URL found for ${GITHUB_USER_REPO} with filter '${FIND_STR}'."
    exit 1
else
    echo "> Release url: ${RELEASE_URL}"
fi

URL_VER="$(echo "${RELEASE_URL}" | grep -oP '(?<=download/)[0-9.]+')"
if [[ -n "${URL_VER}" ]]; then
    echo "> Latest release version: ${URL_VER}"
else
    echo "> Latest release version: unknown"
fi

# Get current version
CURRENT_VER=$(timeout 2 telemt --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -z "${CURRENT_VER}" ]]; then
    echo "> WARNING: Unable to get current telemt version. Proceeding with update anyway."
else
    echo "> Current telemt version: ${CURRENT_VER}"
fi

# Compare versions (only if current version is known and not forced)
if [[ "${FORCE_UPDATE}" != "true" ]] && [[ -n "${CURRENT_VER}" ]]; then
    if [[ "${URL_VER}" == "${CURRENT_VER}" ]] || [[ "$(printf '%s\n%s' "${CURRENT_VER}" "${URL_VER}" | sort -V | head -n1)" == "${URL_VER}" ]]; then
        echo "> No update needed. Current version: ${CURRENT_VER}, Latest version: ${URL_VER}"
        rm -rf ${TEMP_DIR}
        exit 0
    fi
fi

# Download to temp directory
TEMP_DIR=$(mktemp -d)
echo "> Downloading telemt to temp directory ${TEMP_DIR} ..."
curl -Ls ${RELEASE_URL} | tar -xzf - -C ${TEMP_DIR}

# Verify downloaded binary
DOWNLOADED_VER=$(${TEMP_DIR}/telemt --version | awk '{print $2}')
if [[ -z "${DOWNLOADED_VER}" ]]; then
    echo "> ERROR: Unable to get version from downloaded telemt binary."
    rm -rf ${TEMP_DIR}
    exit 1
fi

if [[ "${DOWNLOADED_VER}" != "${URL_VER}" ]]; then
    echo "> ERROR: Downloaded telemt version ${DOWNLOADED_VER} does not match expected ${URL_VER}."
    rm -rf ${TEMP_DIR}
    exit 1
fi

echo "> Downloaded telemt version verified: ${DOWNLOADED_VER}"

echo "> Stopping telemt service"
sudo systemctl stop telemt.service

# Move binary to install dir
echo "> Installing telemt to ${INSTALL_DIR} ..."
sudo mv ${TEMP_DIR}/telemt ${INSTALL_DIR}/telemt
sudo chown root:root ${INSTALL_DIR}/telemt
sudo chmod 755 ${INSTALL_DIR}/telemt

# Clean up temp
rm -rf ${TEMP_DIR}

echo "> Starting telemt service"
if ! systemctl start telemt.service; then
    echo "> ERROR: Failed to start telemt service."
    echo "> Service status:"
    systemctl status telemt.service || true
    echo "> Recent logs:"
    journalctl -u telemt.service -n 20 --no-pager || true
    exit 1
fi

if ! curl -s --max-time 10 http://127.0.0.1:9091/v1/users | jq -r '.data[] | .username as $name | .links.tls[] | select(contains("::") | not) | "\($name): \(.)"' > /dev/null 2>&1; then
    echo "> WARNING: Validation failed. Check telemt service."
fi

