# Optional Skills - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
Optional skill collections that extend Hermes functionality in specialized areas, loaded conditionally based on user needs.

## STRUCTURE
```
optional-skills/
├── creative/             # Extended creative tools
├── mlops/                # Specialized ML operations
├── migration/            # Migration tools (OpenClaw migration, etc.)
├── productivity/         # Additional productivity tools
├── research/             # Advanced research capabilities
├── security/             # Security assessment tools
└── blockchain/           # Blockchain integration skills
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Migration tools | migration/ | Tools for importing from other systems |
| Security tools | security/ | Assessment and security-related skills |
| Blockchain | blockchain/ | Crypto and blockchain skills |
| Extended ML ops | mlops/ | Advanced machine learning operations |

## CONVENTIONS
- Optional skills require explicit installation/enabling
- Skills remain separate from core functionality
- Conditional loading based on requirements

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT hardcode tool references in skill descriptions

## UNIQUE STYLES
- Conditionally-loaded skill sets
- Extended specialization beyond core skills
- Optional dependency requirements
- Modular capability expansion

## COMMANDS
```bash
# Install optional skills
hermes skills install
```

## NOTES
- Optional skills expand Hermes capabilities without bloating core
- Requirements may include additional dependencies
- Skills follow same self-improvement model as core skills