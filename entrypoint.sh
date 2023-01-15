#!/bin/sh -eu

prefFile="${PLEX_MEDIA_SERVER_PREFERENCES_FILE}"

startPlex() {
  exec /usr/lib/plexmediaserver/Plex\ Media\ Server
}

getPref() {
  key="$1"
  
  xmlstarlet sel -T -t -m "/Preferences" -v "@${key}" -n "${prefFile}"
}

setPref() {
  key="$1"
  value="$2"
  
  count="$(xmlstarlet sel -t -v "count(/Preferences/@${key})" "${prefFile}")"
  count=$((count + 0))
  if [ $count -gt 0 ]; then
    xmlstarlet ed --inplace --update "/Preferences/@${key}" -v "${value}" "${prefFile}"
  else
    xmlstarlet ed --inplace --insert "/Preferences"  --type attr -n "${key}" -v "${value}" "${prefFile}"
  fi
}

if [ ! -e "${prefFile}" ]; then
  echo 'Creating empty preferences file'
  mkdir -p "$(dirname "${prefFile}")"
  cat > "${prefFile}" <<-EOF
<?xml version="1.0" encoding="utf-8"?>
<Preferences/>
EOF
fi

machineId="$(getPref 'MachineIdentifier')"
if [ -z "${machineId}" ]; then
  setPref 'MachineIdentifier' "$(uuidgen)"
fi

clientId="$(getPref 'ProcessedMachineIdentifier')"
if [ -z "${clientId}" ]; then
  clientId="$(printf '%s- Plex Media Server' "$(getPref 'MachineIdentifier')" | sha1sum | cut -b 1-40)"
  setPref "ProcessedMachineIdentifier" "${clientId}"
fi

if [ -n "${ADVERTISE_IP:-}" ]; then
  setPref 'customConnections' "${ADVERTISE_IP}"
fi

if [ -n "${ALLOWED_NETWORKS:-}" ]; then
  setPref 'allowedNetworks' "${ALLOWED_NETWORKS}"
fi

token="$(getPref "PlexOnlineToken")"
if [ -n "${PLEX_CLAIM:-}" ] && [ -z "${token}" ]; then
  echo "Attempting to obtain server token from claim token"
    loginInfo="$(curl -X POST \
        -H "X-Plex-Client-Identifier: ${clientId}" \
        -H 'X-Plex-Product: Plex Media Server'\
        -H 'X-Plex-Version: 1.1' \
        -H 'X-Plex-Provides: server' \
        -H 'X-Plex-Platform: Linux' \
        -H 'X-Plex-Platform-Version: 1.0' \
        -H 'X-Plex-Device-Name: PlexMediaServer' \
        -H 'X-Plex-Device: Linux' \
        "https://plex.tv/api/claim/exchange?token=${PLEX_CLAIM}")"
  token="$(echo "$loginInfo" | xmlstarlet sel -T -t -m '/user' -v 'authentication-token')"

  if [ -n "${token}" ]; then
    echo 'Token obtained successfully'
    setPref 'PlexOnlineToken' "${token}"
  fi
fi

setPref 'TranscoderTempDirectory' '/transcode'

startPlex
