#!/data/data/com.termux/files/usr/bin/sh
# Rebuild LearnHarness on Termux and restart the runit service.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
NAME=${LH_SERVICE_NAME:-learnharness}
PORT=${LH_PORT:-3000}
PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
SVDIR=${SVDIR:-$PREFIX/var/service}
LOGDIR=${LOGDIR:-$PREFIX/var/log}

export SVDIR LOGDIR
cd "$ROOT"

command -v node >/dev/null 2>&1 || { echo "error: node not found (pkg install nodejs)" >&2; exit 1; }
[ -f package.json ] || { echo "error: $ROOT is not the repo root" >&2; exit 1; }

install_deps=1
[ "${1:-}" = "--no-install" ] && install_deps=0

# next build rewrites .next; never do that under a running server.
sv down "$NAME" 2>/dev/null || true

if [ "$install_deps" -eq 1 ]; then
  echo "== installing dependencies =="
  ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm install --no-audit --no-fund
fi

echo "== building (webpack; Turbopack is unsupported on Android/arm64) =="
rm -rf .next
NEXT_TELEMETRY_DISABLED=1 \
  NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=3072}" \
  npm run build -- --webpack

echo "== starting service =="
sv up "$NAME" 2>/dev/null || true
sleep 3
sv status "$NAME" || true
curl -fsS -o /dev/null -w "local  %{http_code}\n" --max-time 20 \
  "http://127.0.0.1:$PORT/" || echo "local  unreachable"
