# 本地网关配置

本仓库将五个本地网关 profile 作为项目管理的模板，`~/.hermes/profiles/*` 为运行时状态。

## 目录结构

```
templates/gateway-profiles/
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
└── router/          # 智能路由（端口 8645）
    ├── config.yaml
    ├── SOUL.md
    ├── .env
    └── .env.example
```

## 源配置（Source of Truth）

模板目录包含 `config.yaml`、`SOUL.md`、`.env`、`.env.example`。

### 环境变量

| Profile | `.env` 变量 | 用途 |
|---------|-------------|------|
| hermes | `API_KEY` | Hermes backend API key（Kelivo 对接用） |
| doubao | `API_KEY`, `OPENCODE_GO_API_KEY` | `API_KEY` 用于网关鉴权；`OPENCODE_GO_API_KEY` 用于 opencode-go / kimi-k2.5 模型调用 |
| codecraft | `API_KEY`, `CODECRAFT_BASE_URL`, `THIRD_PARTY_API_KEY` | `API_KEY` 用于网关鉴权；`CODECRAFT_BASE_URL`/`THIRD_PARTY_API_KEY` 用于任意 OpenAI 兼容第三方模型服务 |
| flora | `API_KEY`, `OPENCODE_GO_API_KEY` | `API_KEY` 用于网关鉴权；`OPENCODE_GO_API_KEY` 用于 opencode-go / kimi-k2.5 模型调用 |
| router | `ROUTER_API_KEY`, `HERMES_BACKEND_API_KEY`, `DOUBAO_BACKEND_API_KEY`, `CODECRAFT_BACKEND_API_KEY`, `FLORA_BACKEND_API_KEY` | `ROUTER_API_KEY` 用于 Kelivo 鉴权；后端密钥需与 hermes、doubao、codecraft、flora 的 `API_KEY` 一致 |

模板 `.env` 使用空值占位（如 `API_KEY=`），实际密钥本地填写，不提交到仓库。

`.env.example` 与 `.env` 结构一致，供新部署参考。

### config.yaml 占位符

模板 `config.yaml` 中的 `${VAR}` 占位符在加载时由 `gateway/config.py` 展开：

- `hermes/config.yaml`: `key: "${API_KEY}"`
- `doubao/config.yaml`: `key: "${API_KEY}"`
- `codecraft/config.yaml`: `key: "${API_KEY}"`
- `flora/config.yaml`: `key: "${API_KEY}"`
- `router/config.yaml`: `key: "${ROUTER_API_KEY}"`，backend `api_key: "${HERMES_BACKEND_API_KEY}"` / `"${DOUBAO_BACKEND_API_KEY}"` / `"${CODECRAFT_BACKEND_API_KEY}"` / `"${FLORA_BACKEND_API_KEY}"`

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

### 启动

```bash
./start_all_gateways.sh
```

脚本执行顺序：
1. 同步模板到 `~/.hermes/profiles/*`
2. 校验各 profile `.env` 中的必填变量
3. 检查 router 后端密钥与 hermes/doubao/codecraft/flora 的 `API_KEY` 一致性
4. 停止已有网关进程
5. 依次启动五个网关（带 `-v` 开启 INFO 日志）

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

### 1. 共享 DB + user_id 列

当前每个用户一个独立 `memory.db`（`memories/<user_id>/memory.db`），用户量达到十万级后会产生大量小文件，与原来的 `USER.md`/`MEMORY.md` 方案存在相同目录扩展问题。

**改进方案：** 改为共享数据库 + `user_id` 列：

```sql
CREATE TABLE memory_entries (
    user_id  TEXT NOT NULL,
    target   TEXT NOT NULL,    -- 'memory' 或 'user'
    position INTEGER NOT NULL,
    content  TEXT NOT NULL,
    PRIMARY KEY (user_id, target, position)
);
CREATE INDEX idx_memory_user ON memory_entries(user_id, target);
```

- 所有用户共享一个 `memories.db`（放在 profile 根目录 `~/.hermes/profiles/<name>/memories.db`）
- 查询时 `WHERE user_id = ?`
- 避免 inode 耗尽和目录扫描性能问题
- 需要考虑 guest 用户数据清理策略

### 2. 自定义 Provider 支持

当前 doubao 配置仅支持预定义的 provider（`opencode-go`、`opencode-zen` 等）。需要增加自定义 provider 支持，允许：

- 自定义 API URL（如私有部署的兼容 OpenAI 的推理服务）
- OpenAI Chat Completions 格式（`/v1/chat/completions`）
- 用户在 `config.yaml` 中直接指定 `base_url`、`api_key`、`model` 列表

**配置示例：**

```yaml
model:
  default: my-custom-model
  provider: custom-openai
  custom_providers:
    custom-openai:
      base_url: "https://my-inference-server.example.com/v1"
      api_key_env: MY_CUSTOM_API_KEY
      transport: openai_chat
      models:
        - my-custom-model
        - my-other-model
```

需要改动的代码路径：
- `hermes_cli/auth.py` — 动态注册 provider
- `hermes_cli/runtime_provider.py` — 解析 `custom_providers` 配置
- `hermes_cli/models.py` — 合并自定义模型列表
- `hermes_cli/config.py` — 新增 `model.custom_providers` 配置项
