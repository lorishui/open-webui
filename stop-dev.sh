#!/usr/bin/env bash
# 停止 Open WebUI 前后端开发服务
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$ROOT_DIR/.dev-pids"
BACKEND_PORT="${PORT:-8080}"
FRONTEND_PORT=5173

kill_tree() {
  local pid="$1"
  # 先杀子进程（uvicorn --reload / vite 都会 fork 子进程），再杀父进程
  pkill -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
}

stopped=0

for name in backend frontend; do
  pid_file="$PID_DIR/$name.pid"
  if [[ -f "$pid_file" ]]; then
    pid=$(cat "$pid_file")
    if kill -0 "$pid" 2>/dev/null; then
      echo "[$name] 停止进程 $pid"
      kill_tree "$pid"
      stopped=1
    fi
    rm -f "$pid_file"
  fi
done

# 端口兜底：处理 pid 文件丢失或进程未被清理干净的情况
for port in "$BACKEND_PORT" "$FRONTEND_PORT"; do
  pids=$(lsof -ti ":$port" -sTCP:LISTEN 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    echo "清理端口 $port 上的残留进程: $pids"
    echo "$pids" | xargs kill 2>/dev/null || true
    stopped=1
  fi
done

[[ "$stopped" == "0" ]] && echo "没有运行中的服务" || echo "已停止"
