#!/usr/bin/env python3
"""Static checks for the LoveCards 1Panel package (no Docker required)."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
APP = ROOT / "apps" / "lovecards"
compose_path = APP / "2.4.1" / "docker-compose.yml"
form_path = APP / "2.4.1" / "data.yml"
root_path = APP / "data.yml"

compose = compose_path.read_text(encoding="utf-8")
form = form_path.read_text(encoding="utf-8")
root = root_path.read_text(encoding="utf-8")

# Root metadata
assert "key: lovecards" in root
assert "name: LoveCards" in root
assert "type: website" in root
assert "architectures:" in root and "amd64" in root
assert "website: https://lovecards.cn" in root
assert "github: https://github.com/LoveCards/LoveCardsV2" in root
assert "document: https://docs.lovecards.cn/" in root

# Services
services = re.findall(r"^  (\w+):$", compose, re.M)
assert services == ["lovecards", "mysql"], services
assert "image: lovecards-web-frankenphp:latest" in compose
assert "pull_policy: never" in compose
assert "image: mysql:5.7" in compose
assert "pull_policy: missing" in compose
assert 'container_name: "${CONTAINER_NAME}"' in compose
assert 'container_name: "${CONTAINER_NAME}-mysql"' in compose
assert compose.count("1panel-network") == 3  # two service joins + network definition
assert "external: true" in compose
assert compose.count("createdBy: Apps") == 2
assert '"${PANEL_APP_PORT_HTTP}:80"' in compose
assert "./data/web/config:/app/config" in compose
assert "./data/web/public:/app/public" in compose
assert "./data/mysql/mysql_data:/var/lib/mysql" in compose
assert "./data/mysql/mysql_conf:/etc/mysql/conf.d" in compose
assert "./data/mysql/mysql_logs:/var/log/mysql" in compose
assert "depends_on:" in compose and "mysql" in compose
assert "docker.sock" not in compose
assert "privileged:" not in compose
assert "443:443" not in compose  # single HTTP port only

# Form fields
for env_key in (
    "WEB_SERVER_NAME",
    "MYSQL_ROOT_PASSWORD",
    "MYSQL_PASSWORD",
    "MYSQL_TZ",
    "PANEL_APP_PORT_HTTP",
):
    assert f"envKey: {env_key}" in form, env_key
assert "rule: paramPort" in form
assert "type: password" in form

declared = set(re.findall(r"envKey: (\w+)", form))
referenced = set(re.findall(r"\$\{(\w+)\}", compose))
assert referenced - declared <= {"CONTAINER_NAME"}, referenced - declared
assert declared == {
    "WEB_SERVER_NAME",
    "MYSQL_ROOT_PASSWORD",
    "MYSQL_PASSWORD",
    "MYSQL_TZ",
    "PANEL_APP_PORT_HTTP",
}

# Persisted dirs
for directory in (
    "data/web/config",
    "data/web/public",
    "data/mysql/mysql_data",
    "data/mysql/mysql_conf",
    "data/mysql/mysql_logs",
):
    assert (APP / "2.4.1" / directory / ".gitkeep").is_file(), directory

# No generated init.sh expected (FrankenPHP image runs as root per official Dockerfile chain)
scripts = APP / "2.4.1" / "scripts"
assert not scripts.exists() or not (scripts / "init.sh").exists()

# Logo
logo = (APP / "logo.png").read_bytes()
assert logo.startswith(b"\x89PNG\r\n\x1a\n") and len(logo) > 1000

# README style
readme = (APP / "README.md").read_text(encoding="utf-8")
assert "## 产品介绍" in readme
assert "## 主要功能" in readme
assert "source_evidence" not in readme
readme_en = (APP / "README_en.md").read_text(encoding="utf-8")
assert "## Introduction" in readme_en

print("OK: LoveCards package structure, compose, form fields, volumes, logo, README")
