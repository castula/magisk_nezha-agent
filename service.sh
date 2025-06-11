#!/system/bin/sh
MODDIR=${0%/*}
AGENT="$MODDIR/bin/nezha-agent"
CERT_FILE="$MODDIR/cacerts.pem"

echo "nezha-agent" > /sys/power/wake_lock 2>/dev/null

RETRY_COUNT=0
MAX_RETRY=5
RETRY_INTERVAL=30

has_network() {
  ping -c 3 -W 1 223.5.5.5 >/dev/null 2>&1
  return $?
}

while true; do
  if has_network; then
    export SSL_CERT_FILE="$CERT_FILE"
    "$AGENT" >/dev/null 2>&1 &
    PID=$!
    wait $PID

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRY" ]; then
      sleep 600
      RETRY_COUNT=0
    else
      sleep "$RETRY_INTERVAL"
    fi
  else
    sleep 30
  fi
done
