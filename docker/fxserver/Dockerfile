# Runtime for FXServer + txAdmin.
# The server artifact itself (run.sh + alpine/) lives in the repo root and is
# mounted at /server-data, so updating FXServer = replacing those files.
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# txAdmin keeps its config, admins and deployed servers here
ENV TXHOST_DATA_PATH=/txData
VOLUME /txData

# The repo is mounted here (see docker-compose.yml)
WORKDIR /server-data

EXPOSE 30120/tcp 30120/udp 40120/tcp

# No +exec: txAdmin starts and manages the server
CMD ["bash", "/server-data/run.sh"]
