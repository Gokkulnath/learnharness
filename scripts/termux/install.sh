#!/data/data/com.termux/files/usr/bin/sh
# One-shot LearnHarness setup for Termux: deps -> build -> runit service.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
PORT=${LH_PORT:-3000}
cd "$ROOT"

missing=""
for bin in node npm sv termux-wake-lock; do
  command -v "$bin" >/dev/null 2>&1 || missing="$missing $bin"
done
if [ -n "$missing" ]; then
  echo "error: missing commands:$missing" >&2
  echo "install them with:" >&2
  echo "  pkg install nodejs git termux-services termux-tools" >&2
  exit 1
fi

node_major=$(node -p 'process.versions.node.split(".")[0]')
if [ "$node_major" -lt 20 ]; then
  echo "error: Node $node_major is too old; install Node 20+ (pkg upgrade nodejs)" >&2
  exit 1
fi

echo "== building =="
sh "$ROOT/scripts/termux/build.sh"

echo "== installing service =="
sh "$ROOT/scripts/termux/service.sh" install

echo
echo "done. Local:  http://127.0.0.1:$PORT/"
echo "LAN URL:      http://<this-device-ip>:$PORT/"
echo "logs:         sh scripts/termux/service.sh logs"
echo "PWA install:  open http://localhost:$PORT on this device"
