# CLI - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
Interactive CLI orchestrator with rich TUI, autocomplete, and command management system.

## STRUCTURE
```
hermes_cli/
├── main.py           # Entry point — all `hermes` subcommands
├── config.py         # DEFAULT_CONFIG, OPTIONAL_ENV_VARS, migration
├── commands.py       # Slash command definitions + SlashCommandCompleter
├── callbacks.py      # Terminal callbacks (clarify, sudo, approval)
├── setup.py          # Interactive setup wizard
├── skin_engine.py    # Skin/theme engine — CLI visual customization
├── skills_config.py  # `hermes skills` — enable/disable skills per platform
├── tools_config.py   # `hermes tools` — enable/disable tools per platform
├── skills_hub.py     # `/skills` slash command (search, browse, install)
├── models.py         # Model catalog, provider model lists
├── model_switch.py   # Shared /model switch pipeline (CLI + gateway)
└── auth.py           # Provider credential resolution
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| CLI entry point | main.py | Starting point for hermes commands |
| Configuration | config.py | Default settings and environment vars |
| Slash commands | commands.py | Central registry for all slash commands |
| Command callbacks | callbacks.py | User interaction patterns |
| Setup wizard | setup.py | Initial configuration flow |
| Themes | skin_engine.py | Visual customization system |
| Skills management | skills_config.py | Enable/disable skills |
| Tools management | tools_config.py | Enable/disable tools |
| Model selection | models.py, model_switch.py | Available models and switching |

## CONVENTIONS
- Use CommandDef for slash command definitions
- Follow centralized command registry pattern
- Skin engine uses pure data-driven theming
- Configuration separated into load_cli_config() vs load_config()

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT hardcode cross-tool references in schema descriptions 
- DO NOT use `simple_term_menu` for interactive menus (use curses instead)

## UNIQUE STYLES
- Rich TUI with spinner animations
- Data-driven skin/theming system
- Centralized slash command registry
- Profile-aware configuration system

## COMMANDS
```bash
# Run CLI
hermes
# Test CLI
python -m pytest tests/cli/ -v
```

## NOTES
- Rich and prompt_toolkit for TUI and input
- KawaiiSpinner for animated feedback during API calls
- Profile override mechanism for multi-instance support
- Command registry feeds multiple consumers (autocomplete, help, etc.)