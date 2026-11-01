# FXServer (Linux build) with txAdmin.
# By default it installs the "recommended" artifact. Pin a build with:
#   FIVEM_ARTIFACT_URL=https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/<build>/fx.tar.xz
FROM debian:bookworm-slim

ARG FIVEM_ARTIFACT_URL=""

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/fxserver

RUN url="${FIVEM_ARTIFACT_URL:-$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server | jq -r .recommended_download)}" \
    && echo "Downloading $url" \
    && curl -fsSL "$url" | tar -xJ

# txAdmin keeps its config, admins and deployed servers here
ENV TXHOST_DATA_PATH=/txData
VOLUME /txData

# The repo is mounted here (see docker-compose.yml)
WORKDIR /server-data

EXPOSE 30120/tcp 30120/udp 40120/tcp

# No +exec: txAdmin starts and manages the server
CMD ["/opt/fxserver/run.sh"]
