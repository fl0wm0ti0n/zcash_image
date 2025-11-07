FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ARG USER=zcash
ARG HOME_DIR=/home/${USER}
ARG ZCASH_DIR=/opt/zcash
ARG DATA_DIR=/data

# System-Pakete & Build-Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool \
    ncurses-dev unzip python3 python3-zmq zlib1g-dev curl wget ca-certificates \
    bsdmainutils automake libevent-dev libboost-all-dev libsodium-dev \
    libssl-dev libgtest-dev cargo \
 && rm -rf /var/lib/apt/lists/*

# Rust (für moderne Zcash-Builds erforderlich)
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

# Zcash auschecken und bauen
RUN git clone --depth=1 https://github.com/zcash/zcash.git ${ZCASH_DIR} \
 && cd ${ZCASH_DIR} \
 && ./zcutil/build.sh -j"$(nproc)"

# Parameter (Sprout/Sapling/Orchard) – beim Build abholen, falls gewünscht.
# Alternativ kann das auch zur Laufzeit passieren (EntryPoint prüft ebenfalls).
RUN ${ZCASH_DIR}/zcutil/fetch-params.sh || true

# Nutzer & Datenverzeichnis
RUN useradd -ms /bin/bash ${USER} \
 && mkdir -p ${DATA_DIR} \
 && chown -R ${USER}:${USER} ${DATA_DIR}

# Minimaler EntryPoint: erstellt Standard-config, holt ggf. Params und startet zcashd
COPY --chown=zcash:zcash entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER ${USER}
WORKDIR ${HOME_DIR}

# Standard-Umgebung:
# ZCASH_NETWORK: "mainnet" (default) oder "testnet"
# EXTRA_ARGS: zusätzliche zcashd-Flags (z.B. "-printtoconsole")
ENV ZCASH_NETWORK=mainnet
ENV EXTRA_ARGS=""

# Ports gemäß Doku
#  - 8232 mainnet RPC
#  - 8233 mainnet P2P
#  - 18232 testnet RPC
#  - 18233 testnet P2P
EXPOSE 8232 8233 18232 18233

VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]


