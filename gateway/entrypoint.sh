#!/bin/sh
set -e

if [ -z "$TUNNEL_TOKEN" ]; then
  echo "TUNNEL_TOKEN is required" >&2
  exit 1
fi

# Shut down both processes on exit
cleanup() {
  kill "$NGINX_PID" "$CLOUDFLARED_PID" 2>/dev/null
  wait
}
trap cleanup EXIT TERM INT

# Start nginx in background
nginx -g "daemon off;" &
NGINX_PID=$!

# Start cloudflared in background
cloudflared tunnel --no-autoupdate run --token "$TUNNEL_TOKEN" &
CLOUDFLARED_PID=$!

# Poll — exit if either process dies
while kill -0 "$NGINX_PID" 2>/dev/null && kill -0 "$CLOUDFLARED_PID" 2>/dev/null; do
  sleep 1
done

exit 1
