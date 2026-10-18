#!/bin/sh
# Installs LoveCards 1Panel local-app template and loads the official
# lovecards-web-frankenphp:latest image. Running containers and databases
# are not stopped or deleted by this script.
set -eu

TITLE='LoveCards · 1Panel'
stage=''
backup=''
app_dir=''
committed=0
IMAGE_NAME='lovecards-web-frankenphp:latest'
RELEASE_TAG='v2.4.1'
RELEASE_ZIP_URL="https://github.com/LoveCards/LoveCardsV2/releases/download/${RELEASE_TAG}/lovecards-web-frankenphp.zip"
# Template zip of this installer repository (adjust owner/repo after publish).
TEMPLATE_ZIP_URL='https://codeload.github.com/AidenZhang-AidenNovaLabs/lovecards-1panel/zip/refs/heads/main'
TEMPLATE_REQUIRED='data.yml logo.png README.md 2.4.1/data.yml 2.4.1/docker-compose.yml'

ui_msg() {
    if [ -n "${tui:-}" ]; then
        "$tui" --title "$TITLE" --msgbox "$1" 14 76
    else
        printf '\n%s\n\n' "$1" >&2
        printf '%s' '按 Enter 继续…' >&2
        read -r _ || true
    fi
}
ui_yesno() {
    if [ -n "${tui:-}" ]; then
        "$tui" --title "$TITLE" --defaultno --yesno "$1" 16 76
    else
        printf '\n%s\n继续？[y/N] ' "$1" >&2
        read -r answer || return 1
        case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
    fi
}
ui_menu() {
    if [ -n "${tui:-}" ]; then
        "$tui" --title "$TITLE" --backtitle 'Linux 本地应用安装器 · 不操作运行中的容器' \
            --menu '方向键选择，Tab 切换按钮，Enter 确认，Esc 退出。' 17 76 4 \
            install '安装 / 更新模板并加载官方镜像' \
            check '检查依赖、Docker 镜像和 1Panel 目录' \
            delete '仅删除本地应用模板' \
            exit '退出' 3>&1 1>&2 2>&3
    else
        printf '\nLoveCards · 1Panel Linux 安装器\n' >&2
        printf '%s\n' '1) 安装 / 更新模板并加载官方镜像' '2) 检查依赖、Docker 镜像和 1Panel 目录' '3) 仅删除本地应用模板' '4) 退出' >&2
        printf '%s' '选择 [1-4]: ' >&2
        read -r choice || return 1
        case "$choice" in
            1) printf '%s\n' install ;;
            2) printf '%s\n' check ;;
            3) printf '%s\n' delete ;;
            4) printf '%s\n' exit ;;
            *) return 1 ;;
        esac
    fi
}
fail() {
    printf '%s\n' "$1" >&2
    ui_msg "$1" || true
    exit 1
}
cleanup() {
    if [ -n "$backup" ] && [ "$committed" -eq 0 ] && [ ! -e "$app_dir" ]; then
        if mv "$backup/lovecards" "$app_dir"; then
            printf '%s\n' '旧应用目录已恢复。' >&2
            rmdir "$backup" || true
        else
            printf '恢复失败；旧目录仍保存在 %s/lovecards\n' "$backup" >&2
        fi
    fi
    if [ -n "$stage" ]; then rm -rf -- "$stage"; fi
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM HUP

[ "$(uname -s)" = Linux ] || fail '请在 Linux 1Panel 服务器的交互式终端运行。'
[ -t 0 ] && [ -t 1 ] || fail '需要交互式终端；请下载脚本后执行 sh install.sh，不要管道执行。'
tui=''
if [ -n "${TERM:-}" ] && [ "${TERM:-}" != dumb ] && [ "${LOVECARDS_TEXT:-0}" != 1 ]; then
    if command -v whiptail >/dev/null 2>&1; then
        tui=whiptail
    elif command -v dialog >/dev/null 2>&1; then
        tui=dialog
    fi
fi

if choice=$(ui_menu); then
    :
else
    status=$?
    case "$status" in 1|255) exit 0 ;; esac
    tui=''
    printf '%s\n' 'TUI 后端无法运行，回退到文本菜单。' >&2
    choice=$(ui_menu) || exit 0
fi
case "$choice" in
    exit|'') exit 0 ;;
    install|check|delete) : ;;
    *) fail '无效选项。' ;;
esac

for tool in python3 mktemp awk; do
    command -v "$tool" >/dev/null 2>&1 || fail "缺少依赖：$tool。请安装后重试。"
done
if [ "$choice" != delete ]; then
    command -v curl >/dev/null 2>&1 || fail '缺少依赖：curl。请安装后重试。'
fi
panelctl=$(command -v 1pctl 2>/dev/null) || fail '找不到 1pctl；请在安装了 1Panel 的服务器上运行。'
[ -f "$panelctl" ] && [ -r "$panelctl" ] || fail '无法读取 1pctl。'
base_dir=$(awk '/^[[:space:]]*BASE_DIR=/ {sub(/^[[:space:]]*BASE_DIR=/, ""); print; exit}' "$panelctl")
base_dir=$(python3 - "$base_dir" <<'PY'
import sys
from pathlib import Path
value = sys.argv[1].strip()
if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
    value = value[1:-1]
p = Path(value)
if not p.is_absolute() or any(c in value for c in '\n\r$`') or p == Path('/'):
    sys.exit('1pctl BASE_DIR 无效；未执行其中任何 shell 内容。')
print(p.resolve())
PY
) || fail '无法安全解析 1pctl BASE_DIR。'
local_root="$base_dir/1panel/resource/apps/local"
[ -d "$local_root" ] && [ -w "$local_root" ] || fail "本地应用目录不存在或不可写：$local_root"
app_dir="$local_root/lovecards"
[ ! -L "$app_dir" ] || fail "拒绝替换符号链接：$app_dir"
if [ -e "$app_dir" ]; then
    [ -d "$app_dir" ] && [ -f "$app_dir/data.yml" ] || fail "目标不是已识别的应用目录：$app_dir"
fi

image_present() {
    command -v docker >/dev/null 2>&1 || return 1
    docker image inspect "$IMAGE_NAME" >/dev/null 2>&1
}

if [ "$choice" = delete ]; then
    if [ ! -d "$app_dir" ]; then
        ui_msg "未找到本地应用模板：\n$app_dir\n\n运行中的容器、数据库、Docker 镜像和备份目录未修改。"
        exit 0
    fi
    if [ ! -f "$app_dir/data.yml" ] || [ -L "$app_dir" ]; then
        fail "目标不是可识别的 LoveCards 本地应用目录，已拒绝删除：$app_dir"
    fi
    if ui_yesno "仅删除本地应用模板？\n\n$app_dir\n\n不会停止容器，不会删除数据库，不会删除 Docker 镜像，不会删除应用实际安装目录或运行数据。"; then
        python3 - "$local_root" "$app_dir" <<'PY'
from pathlib import Path
import re
import shutil
import sys
root, app = map(Path, sys.argv[1:])
if app.is_symlink() or app.parent.resolve() != root.resolve() or app.name != 'lovecards':
    sys.exit('目标不在本地应用模板目录，已拒绝删除。')
metadata = app / 'data.yml'
if not app.is_dir() or metadata.is_symlink() or not metadata.is_file():
    sys.exit('目标不是可识别的本地应用模板，已拒绝删除。')
if not re.search(r'^\s+key:\s*[\"\x27]?lovecards[\"\x27]?\s*$', metadata.read_text(encoding='utf-8'), re.M):
    sys.exit('应用标识不是 lovecards，已拒绝删除。')
if (app / '.env').exists():
    sys.exit('目标含运行配置 .env，已拒绝删除；请核对路径。')
shutil.rmtree(app)
PY
        ui_msg "本地应用模板已删除。\n\n运行中的容器、数据库、Docker 镜像和运行数据未修改。"
    else
        ui_msg '已取消，未删除任何文件。'
    fi
    exit 0
fi

if [ "$choice" = check ]; then
    docker_state='未检测到 docker'
    if command -v docker >/dev/null 2>&1; then
        if image_present; then
            docker_state="镜像已就绪：$IMAGE_NAME"
        else
            docker_state="docker 可用，但尚未加载镜像：$IMAGE_NAME"
        fi
    fi
    ui_msg "依赖检查通过。

界面：${tui:-文本模式}
工具：python3 / curl / mktemp / awk
目标：$app_dir
Docker：$docker_state

仅安装应用模板并加载官方镜像；运行中的容器与数据库不变。"
    exit 0
fi

need_image=1
if image_present; then
    need_image=0
fi

if [ "$need_image" -eq 1 ]; then
    if ! command -v docker >/dev/null 2>&1; then
        fail '缺少 docker。请先安装 Docker，再运行本脚本加载官方镜像。'
    fi
    if ui_yesno "将从 GitHub 发行版加载官方镜像 ${IMAGE_NAME}（约 120MB，标签 ${RELEASE_TAG}）。\n\n来源：LoveCards/LoveCardsV2 官方 lovecards-web-frankenphp.zip\n\n若网络无法访问 GitHub，可先手动 docker load 后再继续。\n\n继续？"; then
        :
    else
        exit 0
    fi
else
    if ui_yesno "检测到官方镜像 ${IMAGE_NAME} 已存在。\n\n将跳过镜像下载，仅安装 / 更新 1Panel 本地应用模板。\n\n继续？"; then
        :
    else
        exit 0
    fi
fi

if ui_yesno "来源：AidenZhang-AidenNovaLabs/lovecards-1panel（main）\n镜像：LoveCards/LoveCardsV2 ${RELEASE_TAG}\n\n目标：$app_dir\n\n若目标已存在，将保留完整备份。不会自动安装或更新容器。\n\n继续？"; then
    :
else
    exit 0
fi

stage=$(mktemp -d "$local_root/.lovecards.stage.XXXXXX")

progress_run() {
    if [ -n "${tui:-}" ]; then
        "$tui" --title "$TITLE" --gauge '正在验证 DNS、下载并检查应用包 / 镜像…' 9 76 0
    else
        while IFS= read -r line; do
            case "$line" in
                10) printf '%s\n' '正在准备应用模板…' >&2 ;;
                40) printf '%s\n' '正在处理官方镜像…' >&2 ;;
                100) printf '%s\n' '校验完成。' >&2 ;;
            esac
        done
    fi
}

if ! (
    printf '10\n'
    if python3 - "$stage" "$need_image" "$IMAGE_NAME" "$RELEASE_ZIP_URL" "$TEMPLATE_ZIP_URL" "$TEMPLATE_REQUIRED" "${LOVECARDS_LOCAL_TEMPLATE:-}" 2>"$stage/error.log" <<'PY'
import ipaddress
import os
from pathlib import Path, PurePosixPath
import shutil
import socket
import stat
import subprocess
import sys
import tarfile
from urllib.parse import urlsplit
from zipfile import ZipFile

stage = Path(sys.argv[1])
need_image = sys.argv[2] == '1'
image_name = sys.argv[3]
release_url = sys.argv[4]
template_url = sys.argv[5]
required = set(sys.argv[6].split())
local_template = sys.argv[7].strip()


def https_guard(url: str, expected_host: str) -> None:
    parsed = urlsplit(url)
    if parsed.scheme != 'https' or parsed.netloc != expected_host:
        sys.exit(f'拒绝非官方 HTTPS 地址：{url}')
    addresses = {
        ipaddress.ip_address(row[4][0])
        for row in socket.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)
    }
    if not addresses or any(not ip.is_global or ip.is_reserved or ip.is_multicast for ip in addresses):
        sys.exit('DNS 包含本地、私有或保留地址，拒绝请求。')


def fetch(url: str, dest: Path, expected_host: str, max_bytes: int) -> None:
    https_guard(url, expected_host)
    parsed = urlsplit(url)
    addresses = {
        ipaddress.ip_address(row[4][0])
        for row in socket.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)
    }
    ip = sorted(addresses, key=lambda a: (a.version, int(a)))[0]
    pin = str(ip) if ip.version == 4 else '[' + str(ip) + ']'
    result = subprocess.run(
        [
            'curl', '--fail', '--silent', '--show-error', '--noproxy', '*',
            '--proto', '=https', '--connect-timeout', '15', '--max-time', '1800',
            '--max-filesize', str(max_bytes), '--resolve', parsed.hostname + ':443:' + pin,
            '--output', str(dest), '--write-out', '%{http_code}', url,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode or result.stdout != '200':
        sys.exit('下载失败（不接受重定向）：' + (result.stderr.strip() or result.stdout))
    if dest.stat().st_size > max_bytes:
        sys.exit('下载文件超过限制。')


def safe_extract_zip(archive: Path, dest: Path, max_files=5000, max_total=80 * 1024 * 1024) -> None:
    with ZipFile(archive) as z:
        files = z.infolist()
        if len(files) > max_files or sum(f.file_size for f in files) > max_total:
            sys.exit('压缩包解压体积过大。')
        for entry in files:
            path = PurePosixPath(entry.filename)
            mode = entry.external_attr >> 16
            if path.is_absolute() or '..' in path.parts or '\\' in entry.filename or stat.S_ISLNK(mode):
                sys.exit('压缩包存在不安全路径或符号链接。')
            target = dest / str(path)
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(entry) as src, target.open('wb') as dst:
                shutil.copyfileobj(src, dst)


# 1) Prepare application template under stage/lovecards
local_path = Path(local_template) if local_template else None
if local_path and (local_path / 'data.yml').is_file():
    shutil.copytree(local_path, stage / 'lovecards')
else:
    archive = stage / 'template.zip'
    fetch(template_url, archive, 'codeload.github.com', 20 * 1024 * 1024)
    extract_root = stage / 'template_extract'
    safe_extract_zip(archive, extract_root)
    roots = [p for p in extract_root.iterdir() if p.is_dir()]
    if len(roots) != 1:
        sys.exit('模板压缩包根目录不唯一。')
    candidate = roots[0] / 'apps' / 'lovecards'
    if not (candidate / 'data.yml').is_file():
        sys.exit('模板压缩包缺少 apps/lovecards。')
    shutil.copytree(candidate, stage / 'lovecards')

found = {str(p.relative_to(stage / 'lovecards')).replace('\\', '/').rstrip('/') for p in (stage / 'lovecards').rglob('*') if p.is_file()}
# .gitkeep placeholders are optional; required metadata must exist.
missing = {item for item in required if item not in found}
if missing:
    sys.exit('压缩包缺少必要 1Panel 应用文件：' + ', '.join(sorted(missing)))
print('template-ready', file=sys.stderr)

# 2) Load official image when missing
if need_image:
    print('image-download', file=sys.stderr)
    release_zip = stage / 'lovecards-web-frankenphp.zip'
    fetch(release_url, release_zip, 'github.com', 200 * 1024 * 1024)
    image_dir = stage / 'image_extract'
    safe_extract_zip(release_zip, image_dir, max_files=2000, max_total=200 * 1024 * 1024)
    tar_candidates = list(image_dir.rglob('lovecards-web-frankenphp.tar.gz')) + list(image_dir.rglob('*.tar.gz'))
    if not tar_candidates:
        sys.exit('官方发行包中未找到 Docker 镜像 tar.gz。')
    tar_path = tar_candidates[0]
    # Basic gzip/tar sanity without extracting image layers.
    if tar_path.stat().st_size < 1024 * 1024:
        sys.exit('镜像归档过小，拒绝加载。')
    with tarfile.open(tar_path, 'r:*') as tf:
        names = tf.getnames()
        if len(names) > 20000:
            sys.exit('镜像归档条目过多。')
        if any(name.startswith('/') or '..' in PurePosixPath(name).parts for name in names):
            sys.exit('镜像归档存在不安全路径。')
    result = subprocess.run(
        ['docker', 'load', '-i', str(tar_path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.exit('docker load 失败：' + (result.stderr.strip() or result.stdout))
    result = subprocess.run(
        ['docker', 'image', 'inspect', image_name],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        sys.exit('镜像加载后仍不可用：' + image_name)
print('image-ready', file=sys.stderr)
PY
    then
        printf '100\n'
    else
        : >"$stage/failed"
        printf '100\n'
    fi
) | progress_run; then
    fail '进度窗口被取消；未替换旧目录。'
fi
if [ -f "$stage/failed" ]; then
    detail=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).read_text())' "$stage/error.log")
    fail "下载或校验失败；原应用目录未修改。\n$detail"
fi
[ -d "$stage/lovecards" ] || fail '应用包准备失败；原目录未修改。'
if [ -d "$app_dir" ]; then
    backup=$(mktemp -d "$local_root/.lovecards.backup.XXXXXX")
    mv "$app_dir" "$backup/lovecards" || fail '备份失败；未安装新目录。'
fi
mv "$stage/lovecards" "$app_dir" || fail '替换失败，将恢复旧目录。'
committed=1

image_note='未检测到 docker'
if image_present; then
    image_note="镜像已就绪：$IMAGE_NAME"
fi

ui_msg "完成。请在 1Panel 刷新本地应用并安装 LoveCards / 2.4.1。

目标：$app_dir
备份：${backup:-无}
Docker：$image_note

安装时填写 MySQL root/用户密码与端口；数据库名默认 lovecards。
浏览器打开站点完成安装向导。后台默认地址 /admin。
公网访问建议在 1Panel 网站配置 HTTPS 反向代理。

运行中的容器未修改。"
