# 本地网关配置

本仓库将七个本地网关 profile 作为项目管理的模板，`~/.hermes/profiles/*` 为运行时状态。

## 目录结构

```
templates/
├── gateway-profiles.env.example   # 七个 gateway profile 的统一环境变量示例
└── gateway-profiles/
    ├── hermes/          # 主力 backend（端口 8643）
    │   ├── config.yaml
    │   ├── SOUL.md
    │   ├── .env
    │   └── .env.example
    ├── doubao/          # 豆包 backend（端口 8644，kimi-k2.5 / opencode-go）
    │   ├── config.yaml
    │   ├── SOUL.md
    │   ├── .env
    │   └── .env.example
    ├── codecraft/       # 代码匠 backend（端口 8646，kimi-k2.5 / 自定义 OpenAI 兼容 provider）
    │   ├── config.yaml
    │   ├── SOUL.md
    │   ├── .env
    │   └── .env.example
    ├── flora/           # 小花 backend（端口 8647，kimi-k2.5 / opencode-go）
    │   ├── config.yaml
    │   ├── SOUL.md
    │   ├── .env
    │   └── .env.example
    ├── frontmaster/     # FrontMaster backend（端口 8648，第三方 OpenAI 兼容）
    │   ├── config.yaml
    │   ├── SOUL.md
    │   ├── .env
    │   └── .env.example
    ├── reviewpilot/     # 代码审查 bot（端口 8649，Webhook 8650，docker 沙箱）
    │   ├── config.yaml
    │   ├── SOUL.md
    │   ├── .env
    │   ├── .env.example
    │   └── skills/review/SKILL.md
    └── router/          # 智能路由（端口 8645）
        ├── config.yaml
        ├── SOUL.md
        ├── .env
        └── .env.example
```

## 源配置（Source of Truth）

统一环境变量示例位于 `templates/gateway-profiles.env.example`。

各 profile 目录仍保留 `.env.example`，但它们现在是指向统一示例文件的轻量提示入口；运行时真正使用的仍是每个 profile 自己的 `.env`。

### 环境变量

| Profile | `.env` 变量 | 用途 |
|---------|-------------|------|
| hermes | `API_KEY` | Hermes backend API key（Kelivo 对接用） |
| doubao | `API_KEY`, `OPENCODE_GO_API_KEY` | `API_KEY` 用于网关鉴权；`OPENCODE_GO_API_KEY` 用于 opencode-go / kimi-k2.5 模型调用 |
| codecraft | `API_KEY`, `CODECRAFT_BASE_URL`, `THIRD_PARTY_API_KEY` | `API_KEY` 用于网关鉴权；`CODECRAFT_BASE_URL`/`THIRD_PARTY_API_KEY` 用于任意 OpenAI 兼容第三方模型服务 |
| flora | `API_KEY`, `OPENCODE_GO_API_KEY` | `API_KEY` 用于网关鉴权；`OPENCODE_GO_API_KEY` 用于 opencode-go / kimi-k2.5 模型调用 |
| reviewpilot | `API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_REVIEW_GROUP_ID`, `WEBHOOK_GLOBAL_SECRET`, `REVIEW_PUSH_ROUTE_SECRET` | `API_KEY` 用于网关鉴权；`TELEGRAM_ALLOWED_USERS` 建议仅配置创建者 TGID；`TELEGRAM_REVIEW_GROUP_ID` 为审查推送目标群 |
| router | `ROUTER_API_KEY`, `HERMES_BACKEND_API_KEY`, `DOUBAO_BACKEND_API_KEY`, `CODECRAFT_BACKEND_API_KEY`, `FLORA_BACKEND_API_KEY`, `FRONTMASTER_BACKEND_API_KEY`, `REVIEWPILOT_BACKEND_API_KEY` | `ROUTER_API_KEY` 用于 Kelivo 鉴权；后端密钥需与各 backend 的 `API_KEY` 一致 |

模板 `.env` 使用空值占位（如 `API_KEY=`），实际密钥本地填写，不提交到仓库。

请从 `templates/gateway-profiles.env.example` 中复制对应 profile 的区块到 `templates/gateway-profiles/<profile>/.env`，再按本地环境填写实际值。

### config.yaml 占位符

模板 `config.yaml` 中的 `${VAR}` 占位符在加载时由 `gateway/config.py` 展开：

- `hermes/config.yaml`: `key: "${API_KEY}"`
- `doubao/config.yaml`: `key: "${API_KEY}"`
- `codecraft/config.yaml`: `key: "${API_KEY}"`
- `flora/config.yaml`: `key: "${API_KEY}"`
- `router/config.yaml`: `key: "${ROUTER_API_KEY}"`，backend `api_key: "${HERMES_BACKEND_API_KEY}"` / `"${DOUBAO_BACKEND_API_KEY}"` / `"${CODECRAFT_BACKEND_API_KEY}"` / `"${FLORA_BACKEND_API_KEY}"`
  / `"${FRONTMASTER_BACKEND_API_KEY}"` / `"${REVIEWPILOT_BACKEND_API_KEY}"`

## 多租户用户隔离

Router 和各 backend 的 API server 均支持通过请求头识别用户：

```
X-Hermes-User-ID: <用户ID>
```

- 传入 `X-Hermes-User-ID` → agent 按用户 ID 隔离 memory 和 session
- 未传入 → 网关自动生成 `guest_<指纹>` 作为兜底用户 ID（不建议）

### 当前隔离范围

| 组件 | 隔离方式 | 说明 |
|------|----------|------|
| Memory（记忆） | `memories/<user_id>/memory.db` | 每个 user ID 拥有独立 SQLite 数据库 |
| Session DB | `sessions` 表的 `user_id` 列 | 会话记录按 user_id 区分 |
| Skills | 暂未隔离 | 所有用户共享同一套 skills |

### Memory 后端

Memory 系统支持两种存储后端，通过 `config.yaml` 的 `memory.backend` 配置：

```yaml
memory:
  backend: sqlite    # 或 file（默认）
```

| 后端 | 存储 | 适用场景 |
|------|------|----------|
| `file`（默认） | `memories/<user_id>/MEMORY.md` + `USER.md` | 用户量少、简单场景 |
| `sqlite` | `memories/<user_id>/memory.db` | 用户量多、需要原子写入 |

当前 doubao profile 已启用 `sqlite` 后端。
当前 codecraft profile 也启用 `sqlite` 后端。

## 启停流程

## mac 沙箱准备（Colima + Docker）

如果在 mac 上本地联调并希望 `terminal.backend: docker` 可用，先执行：

```bash
bash scripts/setup_docker_sandbox_mac.sh
```

可选环境变量：

- `COLIMA_CPU`（默认 `4`）
- `COLIMA_MEMORY`（默认 `8`，单位 GiB）
- `COLIMA_DISK`（默认 `80`，单位 GiB）
- `HERMES_SANDBOX_WORKSPACE`（默认 `/tmp/hermes-workspace`）

完成后再执行 `./start_all_gateways.sh`，即可让 codecraft 的 Docker 沙箱配置生效。

## Linux 服务器沙箱准备（Docker，默认 rootless）

在 Linux 服务器上建议优先使用 rootless Docker：

```bash
sudo bash scripts/setup_docker_sandbox_linux.sh
```

常用可选参数：

- `ROOTLESS=true|false`（默认 `true`）
- `TARGET_USER=<username>`（默认当前用户）
- `HERMES_SANDBOX_WORKSPACE=/opt/hermes/workspace`（默认该值）

示例：

```bash
sudo ROOTLESS=true TARGET_USER=hermes HERMES_SANDBOX_WORKSPACE=/opt/hermes/workspace \
  bash scripts/setup_docker_sandbox_linux.sh
```

完成后切换到目标用户验证：

```bash
su - hermes
docker info
```

验证通过后再执行 `./start_all_gateways.sh`。

### 启动

```bash
./start_all_gateways.sh
```

脚本执行顺序：
1. 同步模板到 `~/.hermes/profiles/*`
2. 校验各 profile `.env` 中的必填变量
3. 检查 router 后端密钥与 hermes/doubao/codecraft/flora/frontmaster/reviewpilot 的 `API_KEY` 一致性
4. 停止已有网关进程
5. 依次启动七个网关（带 `-v` 开启 INFO 日志）

所有密钥来自 profile 级 `.env`，不加载项目根目录的 `.env`。

### 停止

```bash
./stop_all_gateways.sh
```

按 profile 名称逐一停止网关进程。

### 日志

网关日志位于 `logs/` 目录：

```
logs/hermes.log
logs/doubao.log
logs/codecraft.log
logs/flora.log
logs/frontmaster.log
logs/reviewpilot.log
logs/router.log
```

启动脚本已加 `-v` 标志，日志级别为 INFO，可追踪以下关键信息：
- `X-Hermes-User-ID` 请求头解析结果
- Guest 用户 ID 生成（当缺少请求头时）
- Memory 目录路径解析
- Memory 后端初始化

## 编辑规则

修改 profile 行为时，编辑 `templates/gateway-profiles/*` 下的文件，然后重新同步或重启（`start_all_gateways.sh` 会自动同步）。

不要直接编辑 `~/.hermes/profiles/*/config.yaml`、`SOUL.md` 或 `.env`——下次同步会覆盖。

## Kelivo 对接

Kelivo 连接配置：

| 参数 | 值 |
|------|-----|
| URL | `http://<IP>:8645` |
| API Key | `ROUTER_API_KEY` 的值 |
| Model | `hermes-agent` 或 `doubao-agent` 或 `codecraft-agent` 或 `flora-agent` |

**务必在每次请求中携带 `X-Hermes-User-ID` 请求头**，否则会生成 guest 用户目录，导致记忆不隔离。

---

## 待办事项

- [ ] 网关层硬鉴权（方案1，暂缓实现）
  - 对“底层行为更新 / 教导模式 / 持久化行为规则修改”增加**代码级硬校验**（非 SOUL 软约束）。
  - 仅允许 Telegram 真实 `from_user.id` 属于授权集合（`8259215216`, `8648124057`）时触发：
    - `skill_manage` 的 create/update（含 teaching-mode 类 skill）
    - 持久化 memory 写入（会改变长期行为）
    - personality/system 风格类全局持久化更新
  - 明确拒绝“消息文本自报 ID”作为授权依据；必须以平台事件身份为准。
  - 目标：避免群聊中伪造身份触发教导、以及跨会话风格污染。
