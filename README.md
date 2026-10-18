# LoveCards · 1Panel

将 [LoveCards](https://github.com/LoveCards/LoveCardsV2)（倾心轻言·微型社区）安装到 1Panel。单 Web 容器，数据库接入 **1Panel 已安装的 MySQL**（与 voicehub / Halo 相同绑定方式），不再捆绑 MySQL、不要求填 root 密码。

- 官方镜像：`lovecards-web-frankenphp:latest`（发行包内 `docker save` 产物，安装器 `docker load`）
- 版本通道：`latest`（滚动）
- 架构：amd64 / arm64
- Web 端口：80（可修改）
- Linux TUI：`whiptail` 优先，`dialog` 备用；无后端时回退文本菜单

## Linux TUI 安装

在 Linux 服务器的交互式 SSH 终端运行，不要管道执行。

```bash
sudo apt update && sudo apt install whiptail python3 curl
# 需已有 Docker 与 1Panel
```

一行下载安装器并打开 TUI：

```bash
(f=$(mktemp) && trap 'rm -f "$f"' EXIT && curl --fail --silent --show-error --proto '=https' -o "$f" https://raw.githubusercontent.com/AidenZhang-AidenNovaLabs/lovecards-1panel/main/install.sh && sudo sh "$f")
```

菜单：**安装 / 更新模板并加载官方镜像** · 检查依赖 · 仅删除模板 · 退出。  
可选：`LOVECARDS_TEXT=1` 强制文本模式；`LOVECARDS_LOCAL_TEMPLATE=/path/to/apps/lovecards` 使用本地模板。

脚本只安装本地应用模板并（在缺失时）`docker load` 官方镜像，**不创建容器、不改数据库**。目标目录由 `1pctl` 的 `BASE_DIR` 解析，默认 `/opt/1panel/resource/apps/local/lovecards`。

## 在 1Panel 安装应用

1. 先通过 1Panel 安装并启动 **MySQL**（5.7+）。
2. 刷新本地应用，安装 `LoveCards / latest`。
3. 表单里：
   - **数据库服务**：选择已安装的 MySQL  
   - **数据库名 / 用户 / 密码**：默认随机生成，一般不用改  
   - **站点监听**：默认 `:80`  
   - **端口**：默认 `80`
4. 安装完成后打开 `http://服务器:端口`，完成 LoveCards 网页向导。  
   向导里的数据库主机填 1Panel 显示的数据库主机（同一 `1panel-network`），库名/用户/密码与表单一致。
5. 后台 `/admin`。公网建议在 1Panel「网站」配置 HTTPS 反向代理。

`init.sh` 会把 1Panel 注入的 `PANEL_DB_*` 写成 ThinkPHP 的 `data/web/.env`（挂载到 `/app/.env`），无需手写配置文件。

## 手动安装

1. 复制 `apps/lovecards` 到 `resource/apps/local/lovecards`。
2. 下载官方 [lovecards-web-frankenphp.zip](https://github.com/LoveCards/LoveCardsV2/releases/tag/v2.4.1)，执行 `docker load -i image/lovecards-web-frankenphp.tar.gz`。
3. 刷新本地应用后安装。

## 校验

```bash
python3 check_package.py
python3 check_installer.py
```

LoveCards 与 Logo 权利归上游，[GPL-3.0](https://github.com/LoveCards/LoveCardsV2/blob/main/LICENSE)。本仓库只提供 1Panel 模板与安装器，不含应用源码。
