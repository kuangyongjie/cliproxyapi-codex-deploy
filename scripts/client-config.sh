#!/usr/bin/env bash
# 生成本地 Codex 客户端配置片段（~/.codex/config.toml + ~/.codex/auth.json）
# 用法：
#   ./scripts/client-config.sh            # 只打印，不写入
#   ./scripts/client-config.sh --write    # 写入 ~/.codex/（已有文件会自动备份）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ -f .env ] || { echo "错误：找不到 .env，请先运行 ./scripts/setup.sh"; exit 1; }
# shellcheck disable=SC1091
set -a; . ./.env; set +a

if [ -z "${PROXY_API_KEY:-}" ]; then
  echo "错误：.env 中 PROXY_API_KEY 为空"
  exit 1
fi
if [ -z "${PROXY_DOMAIN:-}" ]; then
  echo "错误：请先在 .env 中填写 PROXY_DOMAIN（你的代理域名）"
  exit 1
fi

BASE_URL="https://${PROXY_DOMAIN}/v1"

CONFIG_TOML=$(cat <<EOF
model_provider = "cliproxyapi"
model = "gpt-5-codex"
model_reasoning_effort = "high"

[model_providers.cliproxyapi]
name = "cliproxyapi"
base_url = "$BASE_URL"
wire_api = "responses"
EOF
)

AUTH_JSON=$(cat <<EOF
{
  "OPENAI_API_KEY": "$PROXY_API_KEY"
}
EOF
)

if [ "${1:-}" = "--write" ]; then
  mkdir -p ~/.codex
  for f in config.toml auth.json; do
    if [ -f ~/.codex/$f ]; then
      cp ~/.codex/$f ~/.codex/$f.bak.$(date +%Y%m%d%H%M%S)
      echo "已备份 ~/.codex/$f"
    fi
  done
  printf '%s\n' "$CONFIG_TOML" > ~/.codex/config.toml
  printf '%s\n' "$AUTH_JSON" > ~/.codex/auth.json
  echo "已写入 ~/.codex/config.toml 和 ~/.codex/auth.json"
else
  echo "----- ~/.codex/config.toml -----"
  printf '%s\n' "$CONFIG_TOML"
  echo ""
  echo "----- ~/.codex/auth.json -----"
  printf '%s\n' "$AUTH_JSON"
  echo ""
  echo "确认无误后可用 --write 直接写入（会自动备份旧文件）。"
fi
