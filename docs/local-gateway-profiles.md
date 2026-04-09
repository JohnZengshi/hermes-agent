# Local gateway profiles

This repo now treats the three local gateway profiles as project-owned templates, while `~/.hermes/profiles/*` remains runtime state.

## Source of truth

- `templates/gateway-profiles/hermes/`
- `templates/gateway-profiles/doubao/`
- `templates/gateway-profiles/router/`

Each template directory contains the tracked `config.yaml` and `SOUL.md` for that profile.

## Runtime materialization

Run:

```bash
./scripts/sync_gateway_profiles.sh
```

That script overwrites the runtime copies of `config.yaml` and `SOUL.md` in:

- `~/.hermes/profiles/hermes/`
- `~/.hermes/profiles/doubao/`
- `~/.hermes/profiles/router/`

It does not delete sessions, logs, skills, databases, or other runtime files.

## Startup flow

Run:

```bash
./start_all_gateways.sh
```

The startup script now:

1. loads the project `.env` if present,
2. validates the gateway API key variables,
3. syncs tracked templates into `~/.hermes/profiles/*`,
4. starts the three gateways.

## Required environment variables

Set these in the project root `.env`:

```bash
HERMES_BACKEND_API_KEY=...
DOUBAO_BACKEND_API_KEY=...
ROUTER_API_KEY=...
```

The committed template configs intentionally use `${VAR}` placeholders so secrets stay out of git.

## Editing rule

If you want to change profile behavior, edit the files under `templates/gateway-profiles/*` and resync.

Do not hand-edit `~/.hermes/profiles/*/config.yaml` or `SOUL.md` unless you intentionally want a temporary local divergence.
