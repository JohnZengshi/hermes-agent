# Tools - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
Tool implementations with standardized registration pattern. Each tool follows the same schema-registration workflow.

## STRUCTURE
```
tools/
├── registry.py           # Central tool registry (schemas, handlers, dispatch)
├── approval.py           # Dangerous command detection
├── terminal_tool.py      # Terminal orchestration
├── process_registry.py   # Background process management
├── file_tools.py         # File read/write/search/patch
├── web_tools.py          # Web search/extract (Parallel + Firecrawl)
├── browser_tool.py       # Browserbase browser automation
├── code_execution_tool.py # execute_code sandbox
├── delegate_tool.py      # Subagent delegation
├── mcp_tool.py           # MCP client (~1050 lines)
└── environments/         # Terminal backends (local, docker, ssh, modal, daytona, singularity)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Tool registration | registry.py | All tools register themselves at import time |
| New tool creation | Any file in tools/ | Follow registration template in AGENTS.md root |
| Terminal backends | environments/ | Multiple execution environments supported |
| Dangerous command approval | approval.py | Automatic detection and approval system |
| Web search | web_tools.py | Parallel and Firecrawl integrations |
| Browser automation | browser_tool.py | Browserbase integration |

## CONVENTIONS
- Each tool self-registers via `registry.register()` at import time
- All handlers return JSON strings
- Tool schemas follow OpenAI format
- Use `get_hermes_home()` for persistent state storage

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT bypass registry system - always use `registry.register()`
- DO NOT return non-JSON from tool handlers
- DO NOT hardcode `~/.hermes` paths in tools

## UNIQUE STYLES
- Self-registering tool architecture
- Centralized dispatch via registry
- Handler-isolated execution
- State-path abstraction with get_hermes_home()

## COMMANDS
```bash
# Test all tools
python -m pytest tests/tools/ -v
```

## NOTES
- Tools are imported by model_tools.py which triggers _discover_tools()
- Background process notifications controlled by display.background_process_notifications
- Each tool must implement check_requirements() and handler