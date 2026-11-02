# FXServer + txAdmin with the whole city baked in.
# Build from the repo root:
#   docker buildx build --platform linux/amd64 -f docker/fxserver/Dockerfile -t ghcr.io/esuedu/fivem-city .
# Needs artifacts/ (Linux FXServer build) and server-data/resources/ (scripts/install-resources.sh).
FROM debian:bookworm-slim

LABEL org.opencontainers.image.source=https://github.com/esuEdu/fivem-city

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY artifacts/ /opt/fxserver/
COPY server-data/ /server-data/
COPY docker/fxserver/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /opt/fxserver/run.sh

# txAdmin keeps its config, admins and deployed servers here
ENV TXHOST_DATA_PATH=/txData
VOLUME /txData

WORKDIR /server-data

EXPOSE 30120/tcp 30120/udp 40120/tcp

# No +exec: txAdmin starts and manages the server
ENTRYPOINT ["/entrypoint.sh"]
