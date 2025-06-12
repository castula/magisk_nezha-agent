# 哪吒 Magisk 模块介绍

> 💡 本模块由 ChatGPT 协助生成，旨在将 [哪吒监控客户端（nezha-agent）](https://github.com/nezhahq/agent) 通过 Magisk 模块形式集成进 Android 系统，实现无系统权限下的持久运行。
> 
> ⚠️ 模块内预置的 `nezha-agent` 为 **ARM64 架构**，如您的设备为 **ARM (32位)** 或 **x86 架构**，请自行从官方仓库下载对应版本并替换模块中的可执行文件。

## ✅ 使用方法

1. 下载 `module.zip`；
2. 修改模块中的 `/bin/config.yml` 配置文件，填写你的探针信息；
3. 使用 Magisk App 刷入该模块；
4. 重启后自动运行，无需手动启动。

> 💡 `nezha-agent`默认会自动更新，无需操心。

## 🖥️ 探针效果展示

![效果展示](./effect.jpg)

## 🔧 脚本逻辑说明

模块整体逻辑已精简，仅保留必要守护逻辑：

### 🛡️ `service.sh`（系统开机后持续守护）

- 启动前检测网络连接（通过 ping 方式判断）；
- 设置环境变量 `SSL_CERT_FILE`，使用内置证书 `bin/ca.crt`，保证 HTTPS 通信正常；
- 使用 `wake_lock` 防止设备休眠，保证 `nezha-agent` 持续在线；
- 实现稳定的守护重启逻辑：
  - 每次 `nezha-agent` 异常退出后自动重启；
  - 连续失败最多重试 5 次，之后延迟 10 分钟再尝试，避免频繁重启占用系统资源。

## 📁 文件结构

```text
/
├── bin/
│   ├── nezha-agent       # 哪吒探针客户端可执行文件
│   ├── config.yml        # 探针配置文件（需手动填写）
│   └── ca.crt            # 内置根证书文件
├── service.sh            # 后台守护进程脚本
├── module.prop           # Magisk 模块元信息
└── META-INF/             # 安装脚本与兼容文件
