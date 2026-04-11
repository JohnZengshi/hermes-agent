# Gateway - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
Messaging platform gateway supporting multiple platforms (Telegram, Discord, Slack, WhatsApp, Signal, etc.) with session management.

## STRUCTURE
```
gateway/
├── run.py            # Main loop, slash commands, message dispatch
├── session.py        # SessionStore — conversation persistence  
├── platforms/        # Adapters: telegram, discord, slack, whatsapp, homeassistant, signal
└── builtin_hooks/    # Default hooks (boot_md, etc.)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Gateway startup | run.py | Main event loop and command routing |
| Session persistence | session.py | Conversation state management |
| Platform adapters | platforms/ | Individual platform integrations |
| Default behaviors | builtin_hooks/ | Standard hooks at boot time |
| Slash commands | run.py | Command handling shared across platforms |

## CONVENTIONS
- Platform adapters follow base adapter pattern
- Sessions tied to platform-specific identifiers
- Hooks system for extensible behavior
- Message routing via platform-agnostic interface

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT hardcode platform-specific behavior in core gateway
- DO NOT store session state in platform-specific formats

## UNIQUE STYLES
- Adapter pattern for platform integration
- Hook system for extensible behavior
- Platform-agnostic session management
- Token lock system for preventing credential conflicts

## COMMANDS
```bash
# Run gateway
hermes gateway start
# Test gateway
python -m pytest tests/gateway/ -v
```

## NOTES
- Platform adapters should use token locks to prevent credential conflicts
- Gateway has its own slash command registry independent of CLI
- Session management handles conversation continuity across platforms