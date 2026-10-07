# CLIProxyAPI + Codex One-Command Deploy

> [中文](README.md) | English

Put Codex behind your own OpenAI-compatible gateway: one command to start the service with Docker, OAuth state centralized in the proxy layer, one stable `/v1` endpoint shared across machines and tools.

Full walkthrough and troubleshooting: [CLIProxyAPI + Codex Setup: Docker, OAuth & Reverse Proxy Guide](https://aitokenhacks.com/en/posts/cliproxyapi-codex-docker-proxy/) · [中文 README](README.md)

## Architecture (three layers, keep them distinct)

1. **Proxy service** (deployed by this repo): `docker-compose.yml` + `config.yaml`
2. **OAuth login state**: mounted `auth/` directory, survives container rebuilds
3. **Local Codex client**: `~/.codex/config.toml` + `~/.codex/auth.json` — only needs the proxy URL + a downstream key

## Quick start (server side, Linux)

```bash
git clone https://github.com/kuangyongjie/cliproxyapi-codex-deploy.git
cd cliproxyapi-codex-deploy
./scripts/setup.sh
```

The script checks Docker, generates a random `PROXY_API_KEY` into `.env`, renders `config.yaml` from the template, then runs `docker compose up -d`.

Then complete Codex OAuth **on the proxy** (not locally):

```bash
docker compose exec cli-proxy-api /CLIProxyAPI/CLIProxyAPI -no-browser --codex-login
```

Open the printed URL to authorize, and confirm login state landed in `auth/`.

## Client configuration

Set `PROXY_DOMAIN` in `.env`, then:

```bash
./scripts/client-config.sh          # preview only
./scripts/client-config.sh --write  # write to ~/.codex/ (backs up existing files)
```

Don't miss: `base_url` must point at `https://your-domain/v1`, and `wire_api = "responses"`.

## Optional: Nginx HTTPS

`nginx/codex-proxy.conf.example` is a drop-in server block — replace `__PROXY_DOMAIN__`. Keep `/v1/` intact, no rewrites. If you changed `HOST_PORT`, update the port in `proxy_pass` to match.

## Common failures (check these first)

- Container runs but login lost after restart → `auth/` not mounted or empty
- Client can't connect → `base_url` still points at a localhost example
- Domain works but requests 404 → `/v1/` path rewritten or dropped
- Weird behavior → `wire_api = "responses"` was skipped
- Real OpenAI key placed in `auth.json` → not needed, only the proxy's downstream key goes there
- Port 8317 already in use → set `HOST_PORT=18317` (or another free port) in `.env` and re-run `./scripts/setup.sh`; the script pre-checks ports and fails with a clear message

## Maintenance

```bash
./scripts/update.sh   # pull latest image and recreate (auth/ and config.yaml untouched)
docker compose logs -f
```

Design principle: deployment template only, no fork of upstream code. Upstream updates flow through the `eceasy/cli-proxy-api` image, so this repo needs near-zero maintenance.

## Security notes

- `.env` / `config.yaml` / `auth/` are gitignored — **never commit them**
- `remote-management.allow-remote` defaults to off; keep it that way unless you need remote management
