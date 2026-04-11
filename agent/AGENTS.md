# Agent Core - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
Core agent functionality including prompt building, context compression, caching, auxiliary clients, and model metadata.

## STRUCTURE
```
agent/
├── prompt_builder.py     # System prompt assembly
├── context_compressor.py # Auto context compression  
├── prompt_caching.py     # Anthropic prompt caching
├── auxiliary_client.py   # Auxiliary LLM client (vision, summarization)
├── model_metadata.py     # Model context lengths, token estimation
├── models_dev.py         # models.dev registry integration (provider-aware context)
├── display.py            # KawaiiSpinner, tool preview formatting
├── skill_commands.py     # Skill slash commands (shared CLI/gateway)
└── trajectory.py         # Trajectory saving helpers
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Prompt construction | prompt_builder.py | Assembles system prompts from various sources |
| Context compression | context_compressor.py | Auto-compresses context when approaching limits |
| Prompt caching | prompt_caching.py | Handles Anthropic's prompt caching feature |
| Auxiliary processing | auxiliary_client.py | Secondary LLM calls for vision, summarization |
| Model metadata | model_metadata.py | Context windows, token estimations |
| Trajectory management | trajectory.py | Save/load agent execution paths |

## CONVENTIONS
- Use `get_hermes_home()` for profile-aware paths
- Never hardcode `~/.hermes` paths in agent code
- Follow singleton pattern for client instances

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT pass raw hermes home paths - use `get_hermes_home()` 
- DO NOT break prompt caching by altering context mid-conversation

## UNIQUE STYLES
- Centralized display components (KawaiiSpinner)
- Metadata-first model handling
- Fallback-aware auxiliary client system

## COMMANDS
```bash
# Run agent tests
python -m pytest tests/agent/ -v
```

## NOTES
- Agent loop is entirely synchronous in run_conversation()
- Reasoning content stored separately in assistant_msg["reasoning"]
- Trajectory saving preserves full conversation history