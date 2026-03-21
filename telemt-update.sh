#!/bin/bash

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
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

if [[ -f ${DIST_DIR}/telemt ]] || [[ -d ${DIST_DIR}/telemt ]]
then
        echo "> ${DIST_DIR}/telemt EXISTS. Remove them..."
        rm -rf ${DIST_DIR}/telemt
fi

echo "> Searching latest release on GitHub..."
mkdir -p "${DIST_DIR}"
RELEASE_URL=$(curl -sL "https://api.github.com/repos/${GITHUB_USER_REPO}/releases/latest" \
    | jq -r ".assets[] | select(.name | contains(\"${FIND_STR}\") and contains(\"${ARCH_PATTERN}\") and contains(\".tar.gz\") and (contains(\".sha256\") | not)).browser_download_url")
if [[ -z "${RELEASE_URL}" ]] || [[ "${RELEASE_URL}" == "null" ]]; then
    echo "> ERROR: no release URL found for ${GITHUB_USER_REPO} with filter '${FIND_STR}'."
    exit 1
else
    echo "> Release url: ${RELEASE_URL}. Downloading..."
fi

VER="$(echo "${RELEASE_URL}" | grep -oP '(?<=download/)[0-9.]+')"
if [[ -n "${VER}" ]]; then
    echo "> Latest release version: ${VER}"
else
    echo "> Latest release version: unknown"
fi

CURRENT_VER=$(telemt --version | awk '{print $2}')
if [[ -z "${CURRENT_VER}" ]]; then
    echo "> ERROR: Unable to get current telemt version."
    exit 1
fi

if [[ "${URL_VER}" == "${CURRENT_VER}" ]] || [[ "$(printf '%s\n%s' "${CURRENT_VER}" "${URL_VER}" | sort -V | head -n1)" == "${URL_VER}" ]]; then
    echo "> No update needed. Current version: ${CURRENT_VER}, Latest version: ${URL_VER}"
    exit 0
fi

echo "> Stopping telemt service"
sudo systemctl stop telemt.service

curl -Ls ${RELEASE_URL} | tar -xzf - -C ${INSTALL_DIR}

sudo chown root:root ${INSTALL_DIR}/telemt
sudo chmod 755 ${INSTALL_DIR}/telemt

echo "> Starting telemt service"
sudo systemctl start telemt.service
sudo systemctl status telemt.service

if curl -s --max-time 10 http://127.0.0.1:9091/v1/users | jq -r '.data[] | .username as $name | .links.tls[] | select(contains("::") | not) | "\($name): \(.)"'; then
    echo "> Validation successful."
else
    echo "> WARNING: Validation failed. Check telemt service."
fi