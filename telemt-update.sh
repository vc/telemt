#!/bin/bash

if ! command -v jq &> /dev/null
then
    echo "> jq command could not be found. Installing..."
    apt update && apt install -y jq
fi

GITHUB_USER_REPO="telemt/telemt"
FIND_STR="telemt"

DIST_DIR=/opt/telemt.dist

if [[ -f ${DIST_DIR}/telemt ]] || [[ -d ${DIST_DIR}/telemt ]]
then
        echo "> ${DIST_DIR}/telemt EXISTS. Remove them..."
        rm -rf ${DIST_DIR}/telemt
fi

echo "> Searching latest release on GitHub..."
mkdir -p "${DIST_DIR}"
RELEASE_URL="$(curl -sL "https://api.github.com/repos/${GITHUB_USER_REPO}/releases/latest" | jq -r ".assets[] | select(.name | contains(\"${FIND_STR}\")).browser_download_url")"
if [[ -z "${RELEASE_URL}" ]] || [[ "${RELEASE_URL}" == "null" ]]; then
    echo "> ERROR: no release URL found for ${GITHUB_USER_REPO} with filter '${FIND_STR}'."
    exit 1
fi
echo "> Release url: ${RELEASE_URL}. Downloading..."

VER="$(echo "${RELEASE_URL}" | grep -oP '(?<=download/)[0-9.]+')"
if [[ -n "${VER}" ]]; then
    echo "> Latest release version: ${VER}"
else
    echo "> Latest release version: unknown"
fi
wget -qO "${DIST_DIR}/telemt" "${RELEASE_URL}" || { echo "> ERROR: download failed"; exit 1; }

sudo chown root:root ${DIST_DIR}/telemt
sudo chmod 755 ${DIST_DIR}/telemt

echo "> Stopping telemt service"
sudo systemctl stop telemt.service

sudo mv -b --suffix=bak ${DIST_DIR}/telemt /usr/local/bin

echo "> Starting telemt service"
sudo systemctl start telemt.service
sudo systemctl status telemt.service


