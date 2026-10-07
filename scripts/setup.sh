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
  } > .env
  echo "    已写入 .env，可按需修改 PROXY_DOMAIN"
else
  echo "==> .env 已存在，跳过生成"
fi

# 从 .env 读取 key（不 export，避免进子进程环境）
PROXY_API_KEY="$(grep -E '^PROXY_API_KEY=' .env | cut -d= -f2-)"
if [ -z "$PROXY_API_KEY" ]; then
  echo "错误：.env 中 PROXY_API_KEY 为空"
  exit 1
fi

if [ ! -f config.yaml ]; then
  echo "==> 生成 config.yaml"
  sed "s/__PROXY_API_KEY__/$PROXY_API_KEY/" config.example.yaml > config.yaml
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
