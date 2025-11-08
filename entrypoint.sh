#!/usr/bin/env bash
set -euo pipefail

ZCASH_BIN="/usr/local/bin/zcashd"
ZCASH_CLI="/usr/local/bin/zcash-cli"
DATA_DIR="/data"
CONF_DIR="${DATA_DIR}"
CONF_FILE="${CONF_DIR}/zcash.conf"
ZCASH_NETWORK="${ZCASH_NETWORK:-mainnet}"
EXTRA_ARGS="${EXTRA_ARGS:-}"

# Params-Verzeichnis im Volume persistieren und ~/.zcash-params darauf zeigen
PARAMS_DIR="${DATA_DIR}/zcash-params"
mkdir -p "${PARAMS_DIR}"
ln -sfn "${PARAMS_DIR}" "${HOME}/.zcash-params"
export ZCASH_PARAMS_DIR="${PARAMS_DIR}"

# Params bei Bedarf nachladen (idempotent)
if command -v fetch-params.sh >/dev/null 2>&1; then
  fetch-params.sh || true
else
  curl -sSfL https://raw.githubusercontent.com/zcash/zcash/master/zcutil/fetch-params.sh | bash || true
fi

mkdir -p "${CONF_DIR}"

# Default-Config schreiben, wenn nicht vorhanden
if [ ! -f "${CONF_FILE}" ]; then
  RPCUSER="user$(head -c 12 /dev/urandom | tr -dc 'a-z0-9')"
  RPCPASSWORD="$(head -c 24 /dev/urandom | tr -dc 'A-Za-z0-9')"
  cat > "${CONF_FILE}" <<EOF
server=1
rpcuser=\${RPCUSER}
rpcpassword=\${RPCPASSWORD}
# Optional: Logging ins Terminal
printtoconsole=1
# Optional: schnellere Rescans
txindex=1
# Für Containerbetrieb sinnvoll
rpcbind=0.0.0.0
rpcallowip=0.0.0.0/0
EOF
fi

NETWORK_FLAG=""
case "${ZCASH_NETWORK}" in
  testnet|TESTNET) NETWORK_FLAG="-testnet" ;;
  mainnet|MAINNET|"") NETWORK_FLAG="" ;;
  *) echo "Unbekannter ZCASH_NETWORK='${ZCASH_NETWORK}'. Erwarte 'mainnet' oder 'testnet'." >&2; exit 1 ;;
esac

exec "${ZCASH_BIN}" -datadir="${DATA_DIR}" ${NETWORK_FLAG} ${EXTRA_ARGS}


