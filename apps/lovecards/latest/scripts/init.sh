#!/bin/bash

# Generated from official installation evidence:
# - https://github.com/LoveCards/LoveCardsV2/blob/dev/.dev/env/.env.example
# - https://github.com/LoveCards/LoveCardsV2/blob/dev/config/database.php
# - https://github.com/LoveCards/LoveCardsV2/blob/dev/app/system/controller/Install.php

set -eu
if [ ! -f .env ]; then
    echo 'missing 1Panel .env' >&2
    exit 1
fi
python3 - <<'PY'
from pathlib import Path
import re
root = Path('.')
panel = (root / '.env').read_text(encoding='utf-8')
keys = {}
for line in panel.splitlines():
    if '=' not in line or line.lstrip().startswith('#'):
        continue
    k, v = line.split('=', 1)
    keys[k.strip()] = v.strip()
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
