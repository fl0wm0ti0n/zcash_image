FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ARG USER=zcash
ARG ZCASH_DIR=/opt/zcash

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
 && ./zcutil/build.sh -j"$(nproc)" \
 && strip ${ZCASH_DIR}/src/zcashd ${ZCASH_DIR}/src/zcash-cli || true

# Artefakte für die Runtime bereitstellen
RUN mkdir -p /opt/out/bin /opt/out/scripts \
 && cp ${ZCASH_DIR}/src/zcashd ${ZCASH_DIR}/src/zcash-cli /opt/out/bin/ \
 && cp ${ZCASH_DIR}/zcutil/fetch-params.sh /opt/out/scripts/fetch-params.sh


FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ARG USER=zcash
ARG HOME_DIR=/home/${USER}
ARG DATA_DIR=/data

# Nur Runtime-Dependencies installieren
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget \
    libevent-2.1-7 libsodium23 \
    libboost-system1.74.0 libboost-filesystem1.74.0 libboost-thread1.74.0 libboost-chrono1.74.0 libboost-program-options1.74.0 \
    libssl3 libgomp1 \
 && rm -rf /var/lib/apt/lists/*

# Binaries & Param-Skript aus dem Builder übernehmen
COPY --from=builder /opt/out/bin/zcashd /usr/local/bin/zcashd
COPY --from=builder /opt/out/bin/zcash-cli /usr/local/bin/zcash-cli
COPY --from=builder /opt/out/scripts/fetch-params.sh /usr/local/bin/fetch-params.sh
RUN chmod +x /usr/local/bin/fetch-params.sh

# Nutzer & Datenverzeichnis
RUN useradd -ms /bin/bash ${USER} \
 && mkdir -p ${DATA_DIR} \
 && chown -R ${USER}:${USER} ${DATA_DIR}

# EntryPoint
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
