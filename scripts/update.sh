#!/usr/bin/env bash
# 拉取最新镜像并重建容器（auth/ 与 config.yaml 不受影响）
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
docker compose pull
docker compose up -d
docker compose ps
