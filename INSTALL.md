# LoveCards · 1Panel 本地应用（2.4.1）

## Linux TUI 安装

一行下载安装器并运行；临时文件会在退出后删除：

```bash
(f=$(mktemp) && trap 'rm -f "$f"' EXIT && curl --fail --silent --show-error --proto '=https' -o "$f" https://raw.githubusercontent.com/AidenZhang-AidenNovaLabs/lovecards-1panel/main/install.sh && sudo sh "$f")
```

没有 `whiptail`/`dialog` 时，安装器自动回退到普通文本菜单；也可设置 `LOVECARDS_TEXT=1` 强制文本模式。

已克隆本仓库时，可指定本地模板目录：

```bash
sudo env LOVECARDS_LOCAL_TEMPLATE="$(pwd)/apps/lovecards" sh install.sh
```

## 安装前准备

1. Linux 服务器已安装 Docker 与 1Panel（可读 `1pctl`）。
2. 交互式 SSH 终端，具备 root 或 sudo。
3. 能访问 GitHub 发行版下载（或已手动加载镜像）。

## 安装步骤

1. 运行 TUI 安装器：安装/更新本地应用模板，并加载官方镜像 `lovecards-web-frankenphp:latest`。
2. 在 1Panel「应用商店 → 本地应用」刷新，安装 `LoveCards`，版本 `2.4.1`。
3. 表单字段：
   - **站点监听** `WEB_SERVER_NAME`：默认 `:80`（IP 访问）。绑定域名时按上游 `SERVER_NAME` 语法填写。
   - **MySQL root 密码** `MYSQL_ROOT_PASSWORD`：随机生成，可改。
   - **MySQL 密码** `MYSQL_PASSWORD`：应用用户 `lovecards` 的密码，默认 `lovecards`（与上游 Compose 一致），建议随机。
   - **MySQL 时区** `MYSQL_TZ`：默认 `Asia/Shanghai`。
   - **端口** `PANEL_APP_PORT_HTTP`：默认 `80`，映射到容器 `80`。
4. 安装完成后打开 `http://服务器:端口`，按网页向导完成初始化。
   - 数据库服务器：`mysql`
   - 数据库名：`lovecards`
   - 用户名：`lovecards`
   - 密码：安装表单中的 MySQL 密码
5. 后台地址：`/admin`。首次登录后立即修改密码。公网请用 HTTPS 反向代理。

## 与官方 Compose 的对应关系

| 项目 | 官方 | 本包 |
| --- | --- | --- |
| Web 镜像 | `lovecards-web-frankenphp:latest`（docker load） | 相同；`pull_policy: never` |
| 数据库 | `mysql:5.7` | 相同；`pull_policy: missing` |
| 端口 | `80/443/443udp` | 仅 HTTP 一个可配置端口 → 容器 80 |
| Web 卷 | `./data/web/config`、`./data/web/public` | 相同 |
| MySQL 卷 | `./data/mysql/mysql_data\|conf\|logs` | 相同 |
| 环境变量 | `.env` 中 `WEB_SERVER_NAME`、`MYSQL_ROOT_PASSWORD`、`MYSQL_TZ` | 表单化，并增加 `MYSQL_PASSWORD` |
| MySQL 账号 | 库/用户 `lovecards`，密码写死 `lovecards` | 库/用户相同，密码可配置 |
| 网络 | 默认 bridge | `1panel-network` |
| 容器名 | `lovecards-web-frankenphp` / `lovecards-mysql` | `${CONTAINER_NAME}` / `${CONTAINER_NAME}-mysql` |

来源：

- [.docker/frankenphp/Dockerfile](https://github.com/LoveCards/LoveCardsV2/blob/dev/.docker/frankenphp/Dockerfile)
- [.docker/frankenphp/docker-compose.yaml](https://github.com/LoveCards/LoveCardsV2/blob/dev/.docker/frankenphp/docker-compose.yaml)
- [.docker/frankenphp/.env.example](https://github.com/LoveCards/LoveCardsV2/blob/dev/.docker/frankenphp/.env.example)
- [.docker/frankenphp/install.sh](https://github.com/LoveCards/LoveCardsV2/blob/dev/.docker/frankenphp/install.sh)
- [.frankenphp/Caddyfile](https://github.com/LoveCards/LoveCardsV2/blob/dev/.frankenphp/Caddyfile)
- [release-buildDocker.yml](https://github.com/LoveCards/LoveCardsV2/blob/dev/.github/workflows/release-buildDocker.yml)
- [v2.4.1 发行说明与 lovecards-web-frankenphp.zip](https://github.com/LoveCards/LoveCardsV2/releases/tag/v2.4.1)
- [LoveCards README 环境要求](https://github.com/LoveCards/LoveCardsV2#readme)（PHP 8+ / MySQL 5.7+ / 运行目录 `public`）

## 更新与备份

- 更新模板：重新运行 TUI「安装 / 更新」。不会改变已有安装的 `.env` 与数据。
- 更新应用：备份 MySQL 卷与 `data/web` 后，在 1Panel 拉取新版本模板并重建；或手动替换镜像 tar 后 `docker compose up -d`。
- 卸载：在 1Panel 卸载应用（保留数据目录时自行备份）。TUI 的「删除模板」只删 `resource/apps/local/lovecards`。

## 校验

```bash
python3 check_package.py
python3 check_installer.py
```

本机无完整 1Panel 时，**未进行真实 Compose 安装运行测试**。可在测试服务器的**实际安装目录**执行 `docker compose config --quiet` 检查配置；完整 `docker compose config` 可能显示秘密，不要公开其结果。
