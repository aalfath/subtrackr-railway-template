# SubTrackr for Railway: the official image, pinned by version and digest,
# plus a small start script that locks the app with a generated admin login
# before the public port opens.
FROM ghcr.io/bscott/subtrackr:0.7.1@sha256:dc1092d8f9f229cd7980063e3a989402d18f86cb546e45b5b0606e1d32ed153c

ENV GIN_MODE=release \
    DATABASE_PATH=/app/data/subtrackr.db

COPY --chmod=0755 start.sh /usr/local/bin/railway-start.sh

WORKDIR /app
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/railway-start.sh"]
