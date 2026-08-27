#!/bin/sh
# nginx:alpine's own entrypoint runs every executable under /docker-entrypoint.d/ before
# starting nginx, on EVERY container start — so this has to be idempotent. It exists for
# hosts where the exercise media can't arrive the way docker-compose.yml's `media` service
# does it (a separate one-shot container writing into a volume `web` also mounts): Railway
# volumes attach to one service only, so the same download has to happen inside `web` itself,
# once, into a volume mounted at $MEDIA_DIR.
set -e

# docker-compose's `media` service bind-mounts img/ and gif/ straight onto these paths —
# if that already put files here, this host doesn't need us at all.
if [ -n "$(ls -A /usr/share/nginx/html/img 2>/dev/null)" ] && [ -n "$(ls -A /usr/share/nginx/html/gif 2>/dev/null)" ]; then
  exit 0
fi

MEDIA_DIR="${MEDIA_DIR:-/data/media}"
mkdir -p "$MEDIA_DIR/img" "$MEDIA_DIR/gif"

if [ -z "$(ls -A "$MEDIA_DIR/img" 2>/dev/null)" ]; then
  echo "↓ Downloading exercise media (~140 MB, one-time)…"
  git clone --depth 1 https://github.com/hasaneyldrm/exercises-dataset /tmp/exercises-dataset
  cp /tmp/exercises-dataset/images/*.jpg "$MEDIA_DIR/img/"
  cp /tmp/exercises-dataset/videos/*.gif "$MEDIA_DIR/gif/"
  rm -rf /tmp/exercises-dataset
  echo "✓ Exercise media ready ($(ls "$MEDIA_DIR/img" | wc -l) images)."
else
  echo "✓ Exercise media already present in the volume — skipping download."
fi

# The build output has no img/gif of its own (see web/Dockerfile) — point the static root
# at the volume instead. Re-linked every start since /usr/share/nginx/html itself is not
# on the volume and comes back fresh from the image on every deploy.
ln -sfn "$MEDIA_DIR/img" /usr/share/nginx/html/img
ln -sfn "$MEDIA_DIR/gif" /usr/share/nginx/html/gif
