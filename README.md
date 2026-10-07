# CLIProxyAPI + Codex 一键部署

> [English](README.en.md) | 中文

把 Codex 接到自己可控的 OpenAI 兼容网关：Docker 一键起服务，OAuth 状态集中在代理层，多台机器 / 多个工具共用一个 `/v1` 入口。

完整原理与排障说明见博客文章：[CLIProxyAPI + Codex Setup: Docker, OAuth & Reverse Proxy Guide](https://aitokenhacks.com/en/posts/cliproxyapi-codex-docker-proxy/) · [English README](README.en.md)

## 架构（三层别混）

1. **代理服务**（本仓库部署）：`docker-compose.yml` + `config.yaml`
2. **OAuth 登录态**：挂载的 `auth/` 目录，容器重建不丢失
3. **本地 Codex 客户端**：`~/.codex/config.toml` + `~/.codex/auth.json`，只需代理 URL + 下游 key

## 快速开始（服务端，Linux）

```bash
git clone https://github.com/kuangyongjie/cliproxyapi-codex-deploy.git
cd cliproxyapi-codex-deploy
./scripts/setup.sh
```

脚本会做：检查 Docker → 生成随机 `PROXY_API_KEY` 写入 `.env` → 由模板生成 `config.yaml` → `docker compose up -d`。

然后完成 Codex OAuth 登录（在代理上执行，不是本地）：

```bash
docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI -no-browser --codex-login
```

用浏览器打开打印出的 URL 完成授权，确认 `auth/` 目录有文件落盘。

## 客户端配置

在 `.env` 里填好 `PROXY_DOMAIN`（你的代理域名），然后：

```bash
./scripts/client-config.sh          # 预览配置片段
./scripts/client-config.sh --write  # 直接写入 ~/.codex/（自动备份旧文件）
```

关键两行别漏：`base_url` 指向 `https://你的域名/v1`，`wire_api = "responses"`。

## 可选：Nginx HTTPS

`nginx/codex-proxy.conf.example` 是可直接套用的 server 块，把 `__PROXY_DOMAIN__` 换成实际域名。注意 `/v1/` 原样透传，不要 rewrite。

## 常见故障（先查这 5 个）

- 容器在跑但重启后掉登录 → `auth/` 没挂载或目录为空
- 客户端连不上 → `base_url` 还指着 localhost 示例
- 域名能通但请求 404 → `/v1/` 路径被改写或丢失
- 行为诡异 → 漏了 `wire_api = "responses"`
- `auth.json` 里填了真正的 OpenAI key → 不需要，那里只放代理的下游 key
- 8317/1455 端口被占用 → `ss -tlnp | grep 8317` 找到占用者；停掉它或改 `docker-compose.yml` 的端口映射（setup.sh 启动前会自动检查并给出明确报错）

## 维护

```bash
./scripts/update.sh   # 拉新镜像并重建（auth/ 与 config.yaml 不受影响）
docker compose logs -f
```

设计原则：只做部署模板，不 fork 上游代码；上游更新跟着 `eceasy/cli-proxy-api` 镜像走，仓库本身几乎零维护。

## 安全提醒

- `.env` / `config.yaml` / `auth/` 已在 `.gitignore` 中，**不要提交**
- `remote-management.allow-remote` 默认关闭，无远程管理需求别打开
