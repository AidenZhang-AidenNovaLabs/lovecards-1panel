# LoveCards · 1Panel

将 [LoveCards](https://github.com/LoveCards/LoveCardsV2)（倾心轻言·微型社区）安装到 1Panel。应用包含两个服务：官方 FrankenPHP Web 容器与 `mysql:5.7`（与上游 Compose 一致）。

- 官方镜像：`lovecards-web-frankenphp:latest`（发行包内 `docker save` 产物，非公共仓库镜像）
- 版本通道：`2.4.1`（对齐 [v2.4.1](https://github.com/LoveCards/LoveCardsV2/releases/tag/v2.4.1) 发行版）
- 架构：amd64（`mysql:5.7` 官方镜像仅 amd64）
- Web 端口：80（可修改，映射到容器 80）
- Linux TUI：`whiptail` 优先，`dialog` 备用；无可用后端时自动使用普通文本菜单

## Linux TUI 安装

在 Linux 服务器的交互式 SSH 终端运行，不要在 1Panel 计划任务或 `curl | sh` 管道中运行。

Debian / Ubuntu 依赖（自行执行）：

```bash
sudo apt update
sudo apt install whiptail python3 curl docker.io
```

RHEL / Rocky / AlmaLinux 可安装 `dialog python3 curl`。`whiptail/dialog` 是可选项；没有时自动回退到数字文本菜单。也可用 `sudo env LOVECARDS_TEXT=1 sh install.sh` 强制文本模式。

一行下载安装器并打开 TUI：

```bash
(f=$(mktemp) && trap 'rm -f "$f"' EXIT && curl --fail --silent --show-error --proto '=https' -o "$f" https://raw.githubusercontent.com/AidenZhang-AidenNovaLabs/lovecards-1panel/main/install.sh && sudo sh "$f")
```

菜单提供「安装 / 更新模板并加载官方镜像」「检查依赖、Docker 镜像和 1Panel 目录」「仅删除本地应用模板」「退出」。

- 脚本从 `1pctl` 的 `BASE_DIR` 检测本地应用目录；默认 `/opt/1panel/resource/apps/local/lovecards`。
- 安装时若本地无 `lovecards-web-frankenphp:latest`，会从 [LoveCards v2.4.1 发行包](https://github.com/LoveCards/LoveCardsV2/releases/download/v2.4.1/lovecards-web-frankenphp.zip) 下载并 `docker load`（约 120MB）。
- 若已克隆本仓库，可把模板目录指到本地，避免再下模板 ZIP：

  ```bash
  sudo env LOVECARDS_LOCAL_TEMPLATE=/path/to/lovecards-1panel/apps/lovecards sh install.sh
  ```

- 删除选项只删除检测到的 `resource/apps/local/lovecards` 模板，不停止容器、不删数据库、不删 Docker 镜像、不删实际运行数据。
- 下载走 HTTPS、固定已解析公网 IP、不跟随重定向、不使用代理；ZIP 路径与体积校验后再安装。已有模板会备份到 `.lovecards.backup.XXXXXX/lovecards`。
- **脚本仅安装应用商店模板并加载官方镜像，不创建或更新运行容器，不修改数据库。**

## 在 1Panel 安装应用

1. 确认 Docker 可用，且镜像 `lovecards-web-frankenphp:latest` 已加载（TUI 安装步骤会处理）。
2. 在 1Panel 刷新本地应用，安装 `LoveCards / 2.4.1`。
3. 填写站点监听（默认 `:80`）、MySQL root 密码、MySQL 用户密码、时区与 Web 端口。
4. 浏览器打开 `http://服务器:端口`，按向导完成安装。数据库主机填 `mysql`（同 Compose 服务名），库名 `lovecards`，用户 `lovecards`。
5. 后台地址为 `/admin`。公网访问建议在 1Panel「网站」配置 HTTPS 反向代理到本应用端口。

Compose 变量与卷与上游 [`.docker/frankenphp/docker-compose.yaml`](https://github.com/LoveCards/LoveCardsV2/blob/dev/.docker/frankenphp/docker-compose.yaml) 对齐：`data/web/config`、`data/web/public`、`data/mysql/*`。`MYSQL_PASSWORD` 在上游写死为 `lovecards`，本包改为表单字段（默认值相同）以便在 1Panel 中生成随机密码。

## 手动安装与更新

1. 下载本仓库 ZIP，把 `apps/lovecards` 复制到实际 1Panel 根目录的 `resource/apps/local/lovecards`。
2. 下载官方 `lovecards-web-frankenphp.zip`，执行：

   ```bash
   docker load -i image/lovecards-web-frankenphp.tar.gz
   ```

3. 刷新 1Panel 本地应用后安装。

更新前请备份：MySQL 数据卷、应用安装目录（含 `data/web`）。自动迁移可能改变数据库，回退镜像不等于回退数据库。重新运行 TUI 安装器只更新**模板**和（在缺失时）加载镜像，不会改变已有安装的运行配置。

## 验证与限制

```bash
python3 check_package.py
python3 check_installer.py
```

已进行静态检查；尚未在实际 Linux 1Panel 环境完成安装、升级或 TUI 显示验收。镜像来自官方发行包，不是无人值守实时升级通道。

LoveCards 与官方 Logo 的权利属于上游项目，参见 [GPL-3.0](https://github.com/LoveCards/LoveCardsV2/blob/main/LICENSE)。本仓库不包含 LoveCards 应用源码，只提供容器应用模板与安装器。
