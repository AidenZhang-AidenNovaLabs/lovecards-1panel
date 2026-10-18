# LoveCards · 1Panel 本地应用（latest）

## Linux TUI 安装

```bash
(f=$(mktemp) && trap 'rm -f "$f"' EXIT && curl --fail --silent --show-error --proto '=https' -o "$f" https://raw.githubusercontent.com/AidenZhang-AidenNovaLabs/lovecards-1panel/main/install.sh && sudo sh "$f")
```

无 `whiptail`/`dialog` 时回退文本菜单；`LOVECARDS_TEXT=1` 强制文本模式。

## 安装步骤

1. 1Panel 中安装并启动 **MySQL**。
2. 运行 TUI：安装模板；若无镜像则从官方发行包 `docker load`。
3. 1Panel 本地应用安装 `LoveCards`，版本 **latest**。
4. 表单（与 voicehub/Halo 相同，接入 1Panel 数据库）：

   | 字段 | 说明 |
   | --- | --- |
   | 数据库服务 | 选择已安装的 MySQL |
   | 数据库名 / 用户 / 密码 | 自动生成，一般不必改 |
   | 站点监听 | 默认 `:80` |
   | 端口 | 默认 `80` |

   **不需要**填 MySQL root 密码，也不捆绑 `mysql:5.7`。
5. 打开 `http://服务器:端口` 完成网页向导（导入 `data.sql`、生成密钥、写安装锁）。  
   向导数据库主机填 1Panel 显示的数据库主机；库名/用户/密码与安装表单一致。  
   `init.sh` 已写入 ThinkPHP `data/web/.env`（`/app/.env`）。
6. 后台 `/admin`，首次登录后改密。

## 与 voicehub-1panel 的对应

| 项目 | voicehub | LoveCards 本包 |
| --- | --- | --- |
| 版本通道 | latest | latest |
| 数据库 | 1Panel PostgreSQL | 1Panel MySQL |
| 表单 | `PANEL_DB_TYPE` + 随机库名/用户/密码 | 相同 |
| 额外密钥 | JWT 自动生成 | ThinkPHP `.env` 由 `init.sh` 生成 |
| 容器 | 单服务 | 单服务 |

## 来源

- [FrankenPHP Dockerfile / Compose](https://github.com/LoveCards/LoveCardsV2/tree/dev/.docker/frankenphp)
- [config/database.php](https://github.com/LoveCards/LoveCardsV2/blob/dev/config/database.php)（`env('database.*')`）
- [.dev/env/.env.example](https://github.com/LoveCards/LoveCardsV2/blob/dev/.dev/env/.env.example)
- [Install.php](https://github.com/LoveCards/LoveCardsV2/blob/dev/app/system/controller/Install.php)
- [1Panel Halo 数据库绑定](https://github.com/1Panel-dev/appstore/blob/dev/apps/halo/2.26.1/data.yml)
- [v2.4.1 镜像发行包](https://github.com/LoveCards/LoveCardsV2/releases/tag/v2.4.1)

## 更新与备份

- 更新模板：重跑 TUI「安装 / 更新」。
- 备份：1Panel MySQL 数据 + 安装目录 `data/web`（含 `.env`）。
- 卸载：1Panel 卸载应用；TUI「删除模板」只删 `resource/apps/local/lovecards`。
