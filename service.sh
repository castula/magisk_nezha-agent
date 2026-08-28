#!/system/bin/sh
MODDIR=${0%/*}
AGENT="$MODDIR/bin/nezha-agent"
CERT_FILE="$MODDIR/bin/ca.crt"

# 给二进制文件和证书赋予正确的权限
chmod 0755 "$AGENT"
chmod 0644 "$CERT_FILE" # 必须赋予非 Root 用户读取证书的权限

echo "nezha-agent" > /sys/power/wake_lock 2>/dev/null

RETRY_COUNT=0
MAX_RETRY=5
RETRY_INTERVAL=30

# 定义专门运行 nezha-agent 的非 Root UID
AGENT_UID=3005

# 策略路由：为该 UID 添加优先于 VPN 的路由策略 (优先级设为 100)
# 先尝试删除可能存在的旧规则，防止重启脚本时重复添加
ip rule del uidrange $AGENT_UID-$AGENT_UID pref 100 2>/dev/null
ip rule add uidrange $AGENT_UID-$AGENT_UID lookup main pref 100 2>/dev/null

has_network() {
  ping -c 3 -W 1 223.5.5.5 >/dev/null 2>&1
  return $?
}

while true; do
  if has_network; then
    # 以指定的 UID 后台运行 nezha-agent，从而匹配策略路由，避开 VPN 的流量代理
    su $AGENT_UID -c "export SSL_CERT_FILE=\"$CERT_FILE\"; \"$AGENT\"" >/dev/null 2>&1 &
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
