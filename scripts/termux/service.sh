#!/data/data/com.termux/files/usr/bin/sh
# Manage the LearnHarness runit service (termux-services).
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
NAME=${LH_SERVICE_NAME:-learnharness}
HOST=${LH_HOST:-0.0.0.0}
PORT=${LH_PORT:-3000}
PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
SVDIR=${SVDIR:-$PREFIX/var/service}
LOGDIR=${LOGDIR:-$PREFIX/var/log}
UNIT=$SVDIR/$NAME

export SVDIR LOGDIR

usage() {
  cat <<EOF
usage: $0 <install|remove|start|stop|restart|status|logs [lines]>

env: LH_HOST=$HOST LH_PORT=$PORT LH_SERVICE_NAME=$NAME
EOF
}

need_services() {
  command -v sv >/dev/null 2>&1 || {
    echo "error: 'sv' not found. Install the supervisor first:" >&2
    echo "  pkg install termux-services" >&2
    exit 1
  }
}

write_unit() {
  mkdir -p "$UNIT/log"

  cat > "$UNIT/run" <<RUN
#!/data/data/com.termux/files/usr/bin/sh
exec 2>&1
termux-wake-lock
cd "$ROOT" || exit 1
export NEXT_TELEMETRY_DISABLED=1
exec node node_modules/next/dist/bin/next start -H $HOST -p $PORT
RUN

  cat > "$UNIT/log/run" <<'LOG'
#!/data/data/com.termux/files/usr/bin/sh
pwd=${PWD%/*}
service=${pwd##*/}
mkdir -p "$LOGDIR/sv/$service"
exec svlogd -tt "$LOGDIR/sv/$service"
LOG

  chmod 0755 "$UNIT/run" "$UNIT/log/run"
  rm -f "$UNIT/down"
}

cmd=${1:-status}
case "$cmd" in
  install)
    need_services
    [ -f "$ROOT/package.json" ] || { echo "error: $ROOT is not the repo root" >&2; exit 1; }
    write_unit
    service-daemon start >/dev/null 2>&1 || true
    sleep 1
    sv up "$NAME" 2>/dev/null || true
    sleep 3
    sv status "$NAME" || true
    echo "url: http://127.0.0.1:$PORT/"
    ;;
  remove)
    need_services
    sv down "$NAME" 2>/dev/null || true
    rm -rf "$UNIT"
    echo "removed $UNIT"
    ;;
  start)   need_services; sv up "$NAME" ;;
  stop)    need_services; sv down "$NAME" ;;
  restart) need_services; sv restart "$NAME" ;;
  status)
    need_services
    sv status "$NAME" || true
    curl -fsS -o /dev/null -w "local  %{http_code}\n" --max-time 10 \
      "http://127.0.0.1:$PORT/" || echo "local  unreachable"
    ;;
  logs)
    tail -n "${2:-50}" -f "$LOGDIR/sv/$NAME/current"
    ;;
  *)
    usage
    exit 2
    ;;
esac
