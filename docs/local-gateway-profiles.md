# Local gateway profiles

This repo treats the three local gateway profiles as project-owned templates, while `~/.hermes/profiles/*` remains runtime state.

## Source of truth

- `templates/gateway-profiles/hermes/`
- `templates/gateway-profiles/doubao/`
- `templates/gateway-profiles/router/`

Each template directory contains the tracked `config.yaml`, `SOUL.md`, `.env`, and `.env.example`.

### Per-profile environment variables

| Profile | `.env` variables | Purpose |
|---------|-------------------|---------|
| hermes | `API_KEY` | Hermes backend API key (Kelivo-facing) |
| doubao | `API_KEY`, `OPENCODE_ZEN_API_KEY` | `API_KEY` for backend auth; `OPENCODE_ZEN_API_KEY` for the opencode-zen / minimax-m2.5-free provider |
| router | `ROUTER_API_KEY`, `HERMES_BACKEND_API_KEY`, `DOUBAO_BACKEND_API_KEY` | `ROUTER_API_KEY` for Kelivo-facing auth; backend keys must match the corresponding `API_KEY` in hermes and doubao |

The committed template `.env` files use blank values (`API_KEY=`) as placeholders. Fill in real secrets locally — they are never committed.

`.env.example` files mirror `.env` with the same keys and blank values, serving as a reference for new setups.

### config.yaml placeholders

Template `config.yaml` files use `${VAR}` placeholders that are expanded at load time by `gateway/config.py`:

- `hermes/config.yaml`: `key: "${API_KEY}"`
- `doubao/config.yaml`: `key: "${API_KEY}"`
- `router/config.yaml`: `key: "${ROUTER_API_KEY}"`, backend `api_key: "${HERMES_BACKEND_API_KEY}"` / `"${DOUBAO_BACKEND_API_KEY}"`

## Runtime materialization

Run:

```bash
./scripts/sync_gateway_profiles.sh
```

That script overwrites the runtime copies of `config.yaml`, `SOUL.md`, `.env`, and `.env.example` in:

- `~/.hermes/profiles/hermes/`
- `~/.hermes/profiles/doubao/`
- `~/.hermes/profiles/router/`

It does not delete sessions, logs, skills, databases, or other runtime files.

Since `.env` is always overwritten from the template, **edit `templates/gateway-profiles/*/.env` and resync** rather than editing runtime copies.

## Startup flow

Run:

```bash
./start_all_gateways.sh
```

The startup script:

1. syncs tracked templates into `~/.hermes/profiles/*`,
2. validates required keys from each profile's synced `.env`,
3. checks that `HERMES_BACKEND_API_KEY` matches hermes' `API_KEY` and `DOUBAO_BACKEND_API_KEY` matches doubao's `API_KEY`,
4. stops any running gateway processes,
5. starts the three gateways.

It does **not** load the project root `.env`. All secrets come from the per-profile `.env` files.

## Stopping gateways

```bash
./stop_all_gateways.sh
```

This sends a stop signal to each gateway process by profile name.

## Editing rule

If you want to change profile behavior, edit the files under `templates/gateway-profiles/*` and resync (or restart — `start_all_gateways.sh` syncs automatically).

Do not hand-edit `~/.hermes/profiles/*/config.yaml`, `SOUL.md`, or `.env` unless you intentionally want a temporary local divergence — the next sync will overwrite them.