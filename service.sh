#!/system/bin/sh
MODDIR=${0%/*}
AGENT="$MODDIR/bin/nezha-agent"
CERT_FILE="$MODDIR/bin/ca.crt"
CONF_FILE="$MODDIR/bin/config.yml"

# 等待系统完全开机及网络模块就绪
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 3
done

chmod 0755 "$AGENT"

# =========================================================================
# ⚙️ 运行模式选择 (RUN_MODE)
# =========================================================================
# 请将下方 RUN_MODE 的值修改为 1 或 2：
RUN_MODE=2

# 【1】方案1：强行保持 100% 在线（耗电警告 ⚠️）
#   - 逻辑：持有内核级 wake_lock 唤醒锁。
#   - 后果：手机 CPU 将永远无法进入深度休眠。
#   - 体验：由于 CPU 始终在底层活跃，手机可能会增加待机耗电，此模式适合监控24小时运行的设备。

# 【2】方案2：顺应系统休眠（推荐主力机使用 ✅）
#   - 逻辑：不持有唤醒锁，顺应安卓电源管理机制。
#   - 后果：当手机息屏并在口袋里放置一段时间后，安卓系统会进入 Doze（打盹）模式并冻结
#           后台底层网络活动。此时，哪吒面板上该设备会显示离线。
#   - 体验：对手机电池续航影响较小。当你点亮屏幕看微信、回消息时，系统被唤醒，
#           nezha-agent 会瞬间恢复网络并自动在面板上重新上线。
# =========================================================================

if [ "$RUN_MODE" -eq 1 ]; then
  # 方案 A：申请唤醒锁
  echo "nezha-agent" > /sys/power/wake_lock 2>/dev/null
else
  # 方案 B（或切换回方案B时）：确保释放唤醒锁
  echo "nezha-agent" > /sys/power/wake_unlock 2>/dev/null
fi

RETRY_COUNT=0
MAX_RETRY=5
RETRY_INTERVAL=30

has_network() {
  # 容错检测：最多尝试 3 次，每次只发 1 个包等 1 秒
  # 只要有 1 次成功，就立即认定网络畅通并退出检测
  for i in 1 2 3; do
    if ping -c 1 -W 1 223.5.5.5 >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  
  # 如果 3 次全都失败，才真正认定为断网
  return 1
}

while true; do
  if has_network; then
    export SSL_CERT_FILE="$CERT_FILE"
    
    START_TIME=$(date +%s)
    
    # 携带配置文件运行 nezha-agent
    "$AGENT" -c "$CONF_FILE" >/dev/null 2>&1 &
    PID=$!
    wait $PID

    END_TIME=$(date +%s)
    RUN_DURATION=$((END_TIME - START_TIME))

    # 存活超 5 分钟 (300秒) 视为网络切换或正常休眠被杀，而非严重崩溃，清零重试次数
    if [ "$RUN_DURATION" -gt 300 ]; then
      RETRY_COUNT=0
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRY" ]; then
      sleep 600
      RETRY_COUNT=0
    else
      sleep "$RETRY_INTERVAL"
    fi
  else
    # 无网络时短暂休眠，等待网络恢复
    sleep 30
  fi
done
