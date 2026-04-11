# Tests - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
Comprehensive test suite for the Hermes Agent, covering core functionality, CLI, gateway, tools, and integrations.

## STRUCTURE
```
tests/
├── __init__.py
├── test_*.py              # Core functionality tests (model_tools, toolsets, etc.)
├── agent/                 # Agent-specific functionality tests
├── cli/                   # CLI interface and functionality tests
├── cron/                  # Cron scheduler tests
├── gateway/               # Gateway platform integration tests
├── tools/                 # Individual tool tests
├── acp/                   # ACP adapter tests
├── honcho_plugin/         # Honcho memory plugin tests
├── integration/           # Integration tests
├── e2e/                   # End-to-end tests
└── skills/                # Skills functionality tests
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Core agent tests | test_*.py | Basic functionality and model tools |
| CLI tests | cli/ | Terminal interface and commands |
| Gateway tests | gateway/ | Platform integrations |
| Tool tests | tools/ | Individual tool validation |
| Integration tests | integration/ | Cross-component functionality |
| E2E tests | e2e/ | Full workflow validation |

## CONVENTIONS
- Tests must not write to `~/.hermes/` 
- Use `_isolate_hermes_home` fixture for proper isolation
- Profile tests should mock Path.home() appropriately
- Follow pytest conventions with appropriate fixtures

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT write tests that directly access ~/.hermes
- DO NOT hardcode paths assuming default HERMES_HOME

## UNIQUE STYLES
- Comprehensive multi-layer testing (unit, integration, e2e)
- Profile-aware test isolation
- Gateway platform adapter testing
- Tool-specific validation suites

## COMMANDS
```bash
# Run full test suite
python -m pytest tests/ -q
# Run specific test group
python -m pytest tests/tools/ -v
# Run without integration tests
python -m pytest tests/ -k "not integration"
```

## NOTES
- Test suite includes ~3000 tests
- Integration and e2e tests marked separately
- Tests use extensive mocking for isolation
- Profile safety is critical for test reliability