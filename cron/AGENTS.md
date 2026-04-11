# Cron - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
Scheduler system for automated tasks and jobs with delivery to various platforms.

## STRUCTURE
```
cron/
├── scheduler.py    # Main scheduler implementation
├── jobs.py         # Job definitions and management
└── __init__.py
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Scheduler logic | scheduler.py | Core scheduling mechanism |
| Job management | jobs.py | Job definitions and lifecycle |

## CONVENTIONS
- Jobs follow standardized interface for platform delivery
- Scheduling supports time-based and event-based triggers
- Platform delivery abstracted for multiple destinations

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT hardcode platform-specific delivery in job logic

## UNIQUE STYLES
- Natural language schedule specification
- Multi-platform delivery system
- Integration with gateway for message sending

## COMMANDS
```bash
# Run cron tests
python -m pytest tests/cron/ -v
```

## NOTES
- Supports scheduled automations like daily reports, backups
- Integration with messaging platforms for delivery
- Designed for unattended execution