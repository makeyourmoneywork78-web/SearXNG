#!/bin/sh
# Thin wrapper around the stock SearXNG entrypoint that makes the image
# self-contained and Render-ready. It:
#   1. installs our settings.yml into the config volume at runtime,
#   2. injects a random secret_key when the platform did not supply one,
#   3. binds to the platform-provided $PORT (Render sets this),
# then hands off to the unmodified SearXNG entrypoint.
set -eu

CONFIG="/etc/searxng/settings.yml"
SOURCE="/usr/local/searxng/app-settings.yml"

# (1) Install our config at runtime rather than baking it into /etc/searxng at
# build time: /etc/searxng is a VOLUME declared by the base image, and files
# copied into an inherited volume path can be dropped by the builder. Writing
# at container start is reliable. Re-install if the file is missing or is not
# ours (detected via the marker comment), so a stale/default file is corrected.
if [ ! -f "$CONFIG" ] || ! grep -q "epfo_smart_discovery" "$CONFIG" 2>/dev/null; then
  cp -f "$SOURCE" "$CONFIG"
fi

# (2) A stable secret is only needed for web-UI session signing; for this
# API-only backend a fresh random value per boot is fine. Set SEARXNG_SECRET in
# the platform env if you want it stable across restarts.
if [ -z "${SEARXNG_SECRET:-}" ]; then
  SEARXNG_SECRET="$(head -c 32 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 40)"
  export SEARXNG_SECRET
fi

# (3) Honor the platform port. Render injects $PORT (default 10000); locally,
# fall back to the image default (8080) by leaving SEARXNG_PORT unset.
if [ -n "${PORT:-}" ]; then
  export SEARXNG_PORT="$PORT"
fi

exec /usr/local/searxng/entrypoint.sh "$@"
