#!/bin/sh
# Runs the web app, the worker and the cron scheduler in ONE Railway service,
# so a self-hoster only has to configure a single service and one set of
# variables. If any of the three exits, the container exits too and Railway
# restarts it, instead of silently running without the worker.

set -u

PORT="${PORT:-3000}"
export CRON_BASE_URL="${CRON_BASE_URL:-http://127.0.0.1:$PORT}"

# Fill NEXTAUTH_URL from the domain Railway generated, if it was not set.
if [ -z "${NEXTAUTH_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export NEXTAUTH_URL="https://$RAILWAY_PUBLIC_DOMAIN"
fi

npm run start &
WEB=$!
npm run worker &
WORKER=$!
# Give the web app time to boot before the first cron call.
(sleep 60 && exec sh scripts/cron.sh) &
CRON=$!

trap 'kill $WEB $WORKER $CRON 2>/dev/null' INT TERM

while kill -0 $WEB 2>/dev/null && kill -0 $WORKER 2>/dev/null && kill -0 $CRON 2>/dev/null; do
  sleep 5
done

echo "[railway-start] a process exited, stopping the container so Railway restarts it" >&2
kill $WEB $WORKER $CRON 2>/dev/null
exit 1
