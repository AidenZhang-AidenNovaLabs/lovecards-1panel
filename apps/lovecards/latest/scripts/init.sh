#!/bin/bash

# Generated from official installation evidence:
# - https://github.com/LoveCards/LoveCardsV2/blob/dev/.dev/env/.env.example
# - https://github.com/LoveCards/LoveCardsV2/blob/dev/config/database.php
# - https://github.com/LoveCards/LoveCardsV2/blob/dev/app/system/controller/Install.php
# - https://github.com/LoveCards/LoveCardsV2/blob/dev/.github/workflows/release-buildDocker.yml
#   (official package copies /app/public and /app/config into data/web for host mounts)

set -eu
if [ ! -f .env ]; then
    echo 'missing 1Panel .env' >&2
    exit 1
fi

# Seed host mounts from the official image so empty dirs do not shadow /app/public or /app/config.
# Official release zip ships these trees; when using docker load we copy them out of the image.
IMAGE_NAME='lovecards-web-frankenphp:latest'
if [ ! -f data/web/public/index.php ]; then
    if ! command -v docker >/dev/null 2>&1; then
        echo 'docker not found; cannot seed data/web/public from image' >&2
        exit 1
    fi
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "image $IMAGE_NAME not loaded; run install.sh first" >&2
        exit 1
    fi
    cid=$(docker create "$IMAGE_NAME")
    mkdir -p data/web/public data/web/config
    docker cp "$cid:/app/public/." data/web/public/
    docker cp "$cid:/app/config/." data/web/config/
    docker rm "$cid" >/dev/null
    echo 'seeded data/web/public and data/web/config from image'
fi
if [ ! -f data/web/public/index.php ]; then
    echo 'seed failed: data/web/public/index.php missing' >&2
    exit 1
fi

python3 - <<'PY'
from pathlib import Path
root = Path('.')
panel = (root / '.env').read_text(encoding='utf-8')
keys = {}
for line in panel.splitlines():
    if '=' not in line or line.lstrip().startswith('#'):
        continue
    k, v = line.split('=', 1)
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1]
    keys[k.strip()] = v
host = keys.get('PANEL_DB_HOST', '')
port = keys.get('PANEL_DB_PORT', '3306') or '3306'
name = keys.get('PANEL_DB_NAME', '')
user = keys.get('PANEL_DB_USER', '')
password = keys.get('PANEL_DB_USER_PASSWORD', '')
if not host or not name or not user:
    raise SystemExit('PANEL_DB_HOST/NAME/USER missing in .env')
out = root / 'data' / 'web' / '.env'
out.parent.mkdir(parents=True, exist_ok=True)
text = (
    '[DATABASE]\n'
    'TYPE = mysql\n'
    f'HOSTNAME = {host}\n'
    f'DATABASE = {name}\n'
    f'USERNAME = {user}\n'
    f'PASSWORD = {password}\n'
    f'HOSTPORT = {port}\n'
    'CHARSET = utf8mb4\n'
)
out.write_text(text, encoding='utf-8')
print('wrote', out)
PY
chmod 600 data/web/.env || true
