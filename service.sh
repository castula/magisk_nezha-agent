#!/system/bin/sh
MODDIR=${0%/*}
AGENT="$MODDIR/bin/nezha-agent"
CERT_FILE="$MODDIR/bin/ca.crt"
CONF_FILE="$MODDIR/bin/config.yml"

# 等待系统完全开机
until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 5
done

chmod 0755 "$AGENT"
export SSL_CERT_FILE="$CERT_FILE"

# =========================================================================
# ⚙️ 运行模式选择 (RUN_MODE)
# =========================================================================
# 1 = 强行 24 小时在线（持有唤醒锁，阻止深度休眠）
# 2 = 仅亮屏时运行（息屏自动冻结进程，彻底释放 CPU 与基带休眠）
RUN_MODE=2
# =========================================================================

# 判断屏幕是否点亮（兼容各家 ROM 与内核）
is_screen_on() {
  # 优先读取底层显示设备背光亮度（最快、最省 CPU，不唤起 Java 层）
  for bl in /sys/class/leds/lcd-backlight/brightness /sys/class/backlight/*/brightness; do
    if [ -f "$bl" ]; then
      if [ "$(cat "$bl" 2>/dev/null)" -gt 0 ]; then
        return 0 # 亮屏
      else
        return 1 # 息屏
      fi
    fi
  done

  # 备用方案：如果找不到背光节点，通过 dumpsys 判断
  if dumpsys power | grep -E -q "mWakefulness=Awake|Display Power: state=ON"; then
    return 0
  fi
  return 1
}

# 网络连通性轻量检测
has_network() {
  ping -c 1 -W 2 223.5.5.5 >/dev/null 2>&1
  return $?
}

# 清理残留进程与旧锁
killall -9 nezha-agent 2>/dev/null

if [ "$RUN_MODE" -eq 1 ]; then
  echo "nezha-agent" > /sys/power/wake_lock 2>/dev/null
  while true; do
    if has_network; then
      "$AGENT" -c "$CONF_FILE" >/dev/null 2>&1
      sleep 10
    else
      sleep 30
    fi
  done
else
  # 确保释放唤醒锁
  echo "nezha-agent" > /sys/power/wake_unlock 2>/dev/null
  
  AGENT_PID=""
  IS_PAUSED=0

  while true; do
    if is_screen_on; then
      # 【亮屏状态】
      if [ -z "$AGENT_PID" ] || ! kill -0 "$AGENT_PID" 2>/dev/null; then
        # 进程未启动或已意外退出，检测网络后拉起
        if has_network; then
          "$AGENT" -c "$CONF_FILE" >/dev/null 2>&1 &
          AGENT_PID=$!
          IS_PAUSED=0
        else
          sleep 15
          continue
        fi
      elif [ "$IS_PAUSED" -eq 1 ]; then
        # 进程处于息屏冻结状态 -> 发送 SIGCONT 瞬间唤醒恢复
        kill -CONT "$AGENT_PID" 2>/dev/null
        IS_PAUSED=0
      fi
      # 亮屏时每 5 秒检查一次状态
      sleep 5
    else
      # 【息屏状态】
      if [ -n "$AGENT_PID" ] && [ "$IS_PAUSED" -eq 0 ]; then
        if kill -0 "$AGENT_PID" 2>/dev/null; then
          # 发送 SIGSTOP 冻结进程，立即掐断所有 CPU 轮询和网络发包
          kill -STOP "$AGENT_PID" 2>/dev/null
          IS_PAUSED=1
        fi
      fi
      # 息屏后进入休眠等待。当手机进入 Deep Sleep 时，连这个 sleep 计时器也会被内核顺带挂起，完全不耗电
      sleep 10
    fi
  done
fi
