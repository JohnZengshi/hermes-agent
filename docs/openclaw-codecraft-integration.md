# CodeCraft（codecraft-agent）接入说明（内网 OpenClaw）

本文用于指导内网 OpenClaw 接入本仓库提供的 `codecraft-agent`。

## 1. 接入方式（推荐）

推荐通过 **router** 统一接入，而不是直连 backend：

- Router 地址：`http://<HERMES_HOST>:8645`
- 鉴权方式：`Authorization: Bearer <ROUTER_API_KEY>`
- 模型名：`codecraft-agent`
- 协议：OpenAI Chat Completions（`/v1/chat/completions`）

当前 router 已注册模型：

- `hermes-agent`
- `doubao-agent`
- `codecraft-agent`

## 2. 服务端前置条件

确保 Hermes 网关侧已完成以下配置并已启动：

1. `templates/gateway-profiles/codecraft/config.yaml`
   - `model.default: kimi-k2.5`
   - `model.provider: opencode-go`
2. `templates/gateway-profiles/router/config.yaml`
   - 已包含 `codecraft` backend（`model_id: codecraft-agent`）
3. 环境变量（关键项）
   - `templates/gateway-profiles/codecraft/.env`
     - `API_KEY=88888888`
     - `OPENCODE_GO_API_KEY=<你的 opencode-go key>`
   - `templates/gateway-profiles/router/.env`
     - `ROUTER_API_KEY=88888888`
     - `CODECRAFT_BACKEND_API_KEY=88888888`
4. 启动：

```bash
./start_all_gateways.sh
```

## 3. OpenClaw 侧配置（OpenAI 兼容模式）

在 OpenClaw 中新增一个 OpenAI 兼容提供方（字段名按你们内网 OpenClaw 实际配置为准）：

- `base_url`: `http://<HERMES_HOST>:8645/v1`
- `api_key`: `88888888`（即 router 的 `ROUTER_API_KEY`）
- `model`: `codecraft-agent`

> 如果你们 OpenClaw 要求填写完整聊天接口地址，也可直接填：
> `http://<HERMES_HOST>:8645/v1/chat/completions`

## 4. 最小联调用例（先独立验证）

### 4.1 检查模型列表

```bash
curl -sS "http://<HERMES_HOST>:8645/v1/models" \
  -H "Authorization: Bearer 88888888"
```

预期返回中包含：`"id":"codecraft-agent"`。

### 4.2 Chat Completions 测试

```bash
curl -sS "http://<HERMES_HOST>:8645/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 88888888" \
  -H "X-Hermes-User-ID: openclaw_demo_user" \
  -d '{
    "model": "codecraft-agent",
    "messages": [
      {"role": "user", "content": "只回复: openclaw-codecraft-ok"}
    ]
  }'
```

预期：`choices[0].message.content` 返回 `openclaw-codecraft-ok`。

## 5. 多租户建议（强烈推荐）

请 OpenClaw 在每次请求都透传：

- `X-Hermes-User-ID: <业务用户唯一ID>`

这样可以让 Hermes 侧 memory/session 以用户粒度隔离，避免不同用户串记忆。

## 6. 可选：直连 codecraft backend（仅排障使用）

当需要排查 router 问题时，可临时直连：

- 地址：`http://<HERMES_HOST>:8646/v1/chat/completions`
- 鉴权：`Authorization: Bearer 88888888`（codecraft 的 `API_KEY`）
- 模型：`codecraft-agent`

## 7. 常见问题

### 7.1 `401 Unauthorized`

- 检查 `Authorization` 是否是 router key：`Bearer 88888888`
- 检查是否误连了 8646（backend）但用了 router key，或反过来

### 7.2 `model not found`

- 先调 `/v1/models` 看是否包含 `codecraft-agent`
- 检查 `templates/gateway-profiles/router/config.yaml` 是否有 codecraft backend
- 执行 `./start_all_gateways.sh` 重新同步并重启

### 7.3 router 启动失败（环境变量缺失）

- 检查 `templates/gateway-profiles/router/.env` 是否包含：
  - `ROUTER_API_KEY`
  - `HERMES_BACKEND_API_KEY`
  - `DOUBAO_BACKEND_API_KEY`
  - `CODECRAFT_BACKEND_API_KEY`

### 7.4 调用超时或响应慢

- 先看本机日志：
  - `logs/router.log`
  - `logs/codecraft.log`
- 再检查上游模型服务可用性（opencode-go）

---

## 8. 对接参数速查

- Endpoint: `http://<HERMES_HOST>:8645/v1/chat/completions`
- API Key: `88888888`
- Model: `codecraft-agent`
- Required Header: `Authorization: Bearer 88888888`
- Recommended Header: `X-Hermes-User-ID: <user_id>`
