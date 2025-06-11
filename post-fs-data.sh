#!/system/bin/sh
MODDIR=${0%/*}
CERT_FILE="$MODDIR/cacerts.pem"

# 仅首次启动时生成证书
if [ ! -f "$CERT_FILE" ]; then
  cat /system/etc/security/cacerts/* > "$CERT_FILE"
fi

chmod +x "$MODDIR/bin/nezha-agent"
