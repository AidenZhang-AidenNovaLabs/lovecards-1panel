#!/usr/bin/env python3
"""Static checks for the LoveCards 1Panel package (no Docker required)."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
APP = ROOT / "apps" / "lovecards"
compose_path = APP / "latest" / "docker-compose.yml"
form_path = APP / "latest" / "data.yml"
root_path = APP / "data.yml"
init_path = APP / "latest" / "scripts" / "init.sh"

compose = compose_path.read_text(encoding="utf-8")
form = form_path.read_text(encoding="utf-8")
root = root_path.read_text(encoding="utf-8")
init = init_path.read_text(encoding="utf-8") if init_path.is_file() else ""

# Root metadata
assert "key: lovecards" in root
assert "name: LoveCards" in root
assert "type: website" in root
assert "website: https://lovecards.cn" in root
assert "github: https://github.com/LoveCards/LoveCardsV2" in root

# Single web service, 1Panel MySQL binding (no bundled DB)
services = re.findall(r"^  (\w+):$", compose, re.M)
assert services == ["lovecards"], services
assert "image: lovecards-web-frankenphp:latest" in compose
assert "pull_policy: never" in compose
assert "mysql:5.7" not in compose
assert "MYSQL_ROOT_PASSWORD" not in compose
assert 'container_name: "${CONTAINER_NAME}"' in compose
assert 'container_name: "${CONTAINER_NAME}-' not in compose
assert "1panel-network" in compose and "external: true" in compose
assert "createdBy: Apps" in compose
assert '"${PANEL_APP_PORT_HTTP}:80"' in compose
assert "./data/web/config:/app/config" in compose
assert "./data/web/public:/app/public" in compose
assert "./data/web/.env:/app/.env" in compose
assert "depends_on:" not in compose
assert "docker.sock" not in compose

# Form: 1Panel DB service selector + generated credentials
assert "envKey: PANEL_DB_TYPE" in form
assert "type: apps" in form
assert "value: mysql" in form
assert "type: service" in form
assert "envKey: PANEL_DB_HOST" in form
assert form.count("envKey: PANEL_DB_HOST") == 1  # only in child selector
for env_key in ("PANEL_DB_NAME", "PANEL_DB_USER", "PANEL_DB_USER_PASSWORD", "PANEL_APP_PORT_HTTP"):
    assert f"envKey: {env_key}" in form, env_key
assert "WEB_SERVER_NAME" not in form
assert "字符集" not in form
assert 'SERVER_NAME: ":80"' in compose
assert "CHARSET = utf8mb4" in init  # hardcoded, not a form field
assert "type: password" in form
assert "random: true" in form
assert "MYSQL_ROOT_PASSWORD" not in form
assert "rule: paramPort" in form

declared = set(re.findall(r"envKey: (\w+)", form))
referenced = set(re.findall(r"\$\{(\w+)\}", compose))
assert referenced - declared <= {"CONTAINER_NAME", "PANEL_DB_PORT"}, referenced - declared

# init.sh writes ThinkPHP .env from 1Panel .env and seeds public/config from image
assert init.startswith("#!/bin/bash")
assert "Generated from official installation evidence:" in init
assert "data/web/.env" in init
assert "PANEL_DB_HOST" in init
assert "[DATABASE]" in init
assert "docker cp" in init
assert "data/web/public/index.php" in init
assert "lovecards-web-frankenphp:latest" in init
assert "HOST_IP" in init and "0.0.0.0" in init

# .env must be a file mount target, not a directory
env_path = APP / "latest" / "data" / "web" / ".env"
assert env_path.is_file(), "data/web/.env must be a file"

for directory in ("data/web/config", "data/web/public"):
    assert (APP / "latest" / directory / ".gitkeep").is_file(), directory

# Logo + README
logo = (APP / "logo.png").read_bytes()
assert logo.startswith(b"\x89PNG\r\n\x1a\n") and len(logo) > 1000
assert "## 产品介绍" in (APP / "README.md").read_text(encoding="utf-8")

print("OK: latest package uses 1Panel MySQL binding, no bundled MySQL, init.sh writes ThinkPHP .env")
