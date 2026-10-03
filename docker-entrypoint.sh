#!/bin/bash
set -e

# 启动虚拟显示
Xvfb :99 -screen 0 1280x800x24 -nolisten tcp &
export DISPLAY=:99

# 等待 Xvfb 就绪
sleep 1

# 启动 x11vnc（无密码，仅本地 VNC）
if [ -n "$VNC_PASSWORD" ]; then
    x11vnc -display :99 -rfbauth <(x11vnc -storepasswd "$VNC_PASSWORD" /tmp/vncpass && echo /tmp/vncpass) -forever -shared &
else
    x11vnc -display :99 -nopw -forever -shared &
fi

# 启动 noVNC（端口 6080 -> VNC 5900）
websockify --web=/usr/share/novnc 6080 localhost:5900 &

# Handle APP_PASSWORD auto-generation
DATA_DIR="/app/data"
mkdir -p "$DATA_DIR"

if [ "$DISABLE_PASSWORD" = "true" ] || [ "$DISABLE_PASSWORD" = "1" ]; then
    export APP_PASSWORD=""
elif [ -z "$APP_PASSWORD" ]; then
    if [ -f "${DATA_DIR}/app_password.txt" ]; then
        APP_PASSWORD=$(cat "${DATA_DIR}/app_password.txt")
    else
        APP_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16 || true)
        if [ -n "$APP_PASSWORD" ]; then
            echo "$APP_PASSWORD" > "${DATA_DIR}/app_password.txt"
            echo "======================================================="
            echo "Auto-generated APP_PASSWORD: $APP_PASSWORD"
            echo "Saved to ${DATA_DIR}/app_password.txt"
            echo "If you want to disable password protection, set DISABLE_PASSWORD=true"
            echo "======================================================="
        fi
    fi
    export APP_PASSWORD
fi

# 启动 FastAPI 后端
exec uvicorn main:app --host 0.0.0.0 --port 8000
