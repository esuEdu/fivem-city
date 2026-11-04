# FXServer + txAdmin. Built by docker-compose.yml (docker compose up -d --build), which also mounts the repo's
# server-data/ over the copy in the image; see docs/docker.md.
#
# FXServer is downloaded and extracted inside the build (not copied from the host),
# because the artifact relies on symlinks that Windows filesystems break.
# Pin a build with --build-arg FIVEM_ARTIFACT_URL=.../build_proot_linux/master/<build>/fx.tar.xz

FROM debian:bookworm-slim AS artifact
ARG FIVEM_ARTIFACT_URL=""
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq xz-utils \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/fxserver
RUN url="${FIVEM_ARTIFACT_URL:-$(curl -fsSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server | jq -r .recommended_download)}" \
    && echo "Downloading $url" \
    && curl -fsSL "$url" | tar -xJ

FROM debian:bookworm-slim

LABEL org.opencontainers.image.source=https://github.com/esuEdu/fivem-city

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=artifact /opt/fxserver/ /opt/fxserver/
COPY server-data/ /server-data/
COPY docker/fxserver/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# txAdmin keeps its config, admins and deployed servers here
ENV TXHOST_DATA_PATH=/txData
VOLUME /txData

WORKDIR /server-data

EXPOSE 30120/tcp 30120/udp 40120/tcp

# No +exec: txAdmin starts and manages the server
ENTRYPOINT ["/entrypoint.sh"]
