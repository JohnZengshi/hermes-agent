# ACP Adapter - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
ACP server for VS Code / Zed / JetBrains integration, enabling IDE-based agent interaction.

## STRUCTURE
```
acp_adapter/
├── __main__.py       # Entry point for ACP adapter
├── entry.py          # Main entry point script
├── server.py         # ACP server implementation
├── session.py        # Session management for ACP
├── events.py         # Event handling for ACP
├── tools.py          # ACP-specific tools
├── auth.py           # Authentication for ACP
└── permissions.py    # Permission management for ACP
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Server implementation | server.py | Core ACP protocol handling |
| Entry points | __main__.py, entry.py | Starting the ACP adapter |
| Session management | session.py | ACP session handling |
| Tool integration | tools.py | IDE-specific tool access |
| Authentication | auth.py | ACP connection authentication |

## CONVENTIONS
- Follows ACP (Agent Communication Protocol) specifications
- IDE-integrated agent functionality
- Session-based interaction model

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT bypass authentication in ACP connections

## UNIQUE STYLES
- Direct IDE integration via ACP
- Session-based interaction model
- Permission-managed tool access

## COMMANDS
```bash
# Run ACP adapter
hermes-acp
```

## NOTES
- Enables integration with VS Code, Zed, and JetBrains IDEs
- Provides editor-native agent experiences
- Uses ACP protocol for secure communication