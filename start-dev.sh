#!/usr/bin/env bash
# 启动 Open WebUI 前后端开发服务
# 后端: http://localhost:8080  前端: http://localhost:5173
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
LOG_DIR="$ROOT_DIR/logs"
PID_DIR="$ROOT_DIR/.dev-pids"
PYENV_ENV="${PYENV_ENV:-open-webui}"
BACKEND_PORT="${PORT:-8080}"
FRONTEND_PORT=5173

mkdir -p "$LOG_DIR" "$PID_DIR"

port_in_use() { lsof -i ":$1" -sTCP:LISTEN >/dev/null 2>&1; }

# ── 后端 ──────────────────────────────────────────────────────────────────────
if port_in_use "$BACKEND_PORT"; then
  echo "[backend] 端口 $BACKEND_PORT 已被占用，跳过后端启动"
else
  KEY_FILE="$BACKEND_DIR/.webui_secret_key"
  if [[ ! -f "$KEY_FILE" ]]; then
    echo "[backend] 生成 WEBUI_SECRET_KEY..."
    head -c 24 /dev/random | base64 > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
  fi

  echo "[backend] 启动中 (pyenv: $PYENV_ENV, port: $BACKEND_PORT)..."
  (
    cd "$BACKEND_DIR"
    export WEBUI_SECRET_KEY="$(cat "$KEY_FILE")"
    export PYENV_VERSION="$PYENV_ENV"
    export PORT="$BACKEND_PORT"
    exec bash dev.sh
  ) > "$LOG_DIR/backend.log" 2>&1 &
  echo $! > "$PID_DIR/backend.pid"
fi

# ── 前端 ──────────────────────────────────────────────────────────────────────
if port_in_use "$FRONTEND_PORT"; then
  echo "[frontend] 端口 $FRONTEND_PORT 已被占用，跳过前端启动"
else
  echo "[frontend] 启动中 (port: $FRONTEND_PORT)..."
  (
    cd "$ROOT_DIR"
    exec npm run dev
  ) > "$LOG_DIR/frontend.log" 2>&1 &
  echo $! > "$PID_DIR/frontend.pid"
fi

# ── 等待就绪 ──────────────────────────────────────────────────────────────────
echo "等待服务就绪..."
for _ in $(seq 1 60); do
  backend_ok=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$BACKEND_PORT/health" 2>/dev/null || true)
  frontend_ok=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$FRONTEND_PORT/" 2>/dev/null || true)
  [[ "$backend_ok" == "200" && "$frontend_ok" =~ ^(200|304)$ ]] && break
  sleep 2
done

echo ""
echo "后端: http://localhost:$BACKEND_PORT  (health: ${backend_ok:-未启动})"
echo "前端: http://localhost:$FRONTEND_PORT  (status: ${frontend_ok:-未启动})"
echo "日志: $LOG_DIR/backend.log / $LOG_DIR/frontend.log"
echo "停止: ./stop-dev.sh"
