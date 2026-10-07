#!/usr/bin/env bash
# 一键部署：检查环境 -> 生成 key 与 config.yaml -> 启动容器
# 用法：
#   git clone https://github.com/kuangyongjie/cliproxyapi-codex-deploy.git
#   cd cliproxyapi-codex-deploy
#   ./scripts/setup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> 检查 Docker 环境"
command -v docker >/dev/null 2>&1 || { echo "错误：未找到 docker，请先安装 Docker"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "错误：docker compose 插件不可用"; exit 1; }

port_in_use() { # $1=端口；127.0.0.1 能连上即视为被占用（纯 bash，无外部依赖）
  (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null
}

echo "==> 准备目录"
mkdir -p auth

gen_key() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
  else
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 48
  fi
}

if [ ! -f .env ]; then
  echo "==> 生成 .env（含随机 PROXY_API_KEY）"
  KEY="$(gen_key)"
  {
    echo "PROXY_API_KEY=$KEY"
    echo "PROXY_DOMAIN=${PROXY_DOMAIN:-}"
    echo "HOST_PORT=${HOST_PORT:-8317}"
  } > .env
  echo "    已写入 .env，可按需修改 PROXY_DOMAIN / HOST_PORT"
else
  echo "==> .env 已存在，跳过生成"
fi

# 读取宿主机映射端口（默认 8317，可在 .env 中修改）
HOST_PORT="$(grep -E '^HOST_PORT=' .env | cut -d= -f2-)"
HOST_PORT="${HOST_PORT:-8317}"

echo "==> 检查端口占用（宿主机 $HOST_PORT / 1455）"
our_cid="$(docker compose ps -q cli-proxy-api 2>/dev/null | head -1)"
our_running="false"
[ -n "$our_cid" ] && our_running="$(docker inspect -f '{{.State.Running}}' "$our_cid" 2>/dev/null || echo false)"
if [ "$our_running" != "true" ]; then
  for p in "$HOST_PORT" 1455; do
    if port_in_use "$p"; then
      echo "错误：宿主机端口 $p 已被占用，容器无法启动"
      echo "排查占用：ss -tlnp | grep $p   或   docker ps -a"
      echo "处理：在 .env 中把 HOST_PORT 换成空闲端口后重跑本脚本"
      exit 1
    fi
  done
else
  echo "    cli-proxy-api 已在运行，跳过端口检查"
fi

# 从 .env 读取 key（不 export，避免进子进程环境）
PROXY_API_KEY="$(grep -E '^PROXY_API_KEY=' .env | cut -d= -f2-)"
if [ -z "$PROXY_API_KEY" ]; then
  echo "错误：.env 中 PROXY_API_KEY 为空"
  exit 1
fi

yaml_sq() { # YAML single-quote a string so any special chars stay safe
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

if [ ! -f config.yaml ]; then
  echo "==> 生成 config.yaml"
  # key 先做 YAML 单引号转义，再转义 sed 特殊字符后注入模板
  esc_key="$(yaml_sq "$PROXY_API_KEY" | sed 's/[|&]/\\&/g')"
  sed "s|__PROXY_API_KEY__|$esc_key|" config.example.yaml > config.yaml
else
  echo "==> config.yaml 已存在，跳过生成（如需更换 key 请手动编辑）"
fi

echo "==> 启动容器"
docker compose up -d
sleep 2
docker compose ps

echo ""
echo "部署完成。接下来两步："
echo "  1) 在代理上完成 Codex OAuth 登录："
echo "     docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI -no-browser --codex-login"
echo "     完成后确认 auth/ 目录下有登录状态文件落盘。"
echo "  2) 生成本地 Codex 客户端配置片段："
echo "     ./scripts/client-config.sh"
