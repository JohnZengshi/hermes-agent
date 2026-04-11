# Environments - Development Guide

**Generated:** 2026-04-12
**Commit:** abc1234
**Branch:** main

## OVERVIEW
RL training environments and benchmark systems for agent testing and development.

## STRUCTURE
```
environments/
├── __init__.py
├── hermes_swe_env/         # SWE environment for Hermes
├── terminal_test_env/      # Terminal testing environment
├── tool_call_parsers/      # Parser implementations for different models
├── benchmarks/             # Benchmark suites (yc_bench, tblite, terminalbench_2)
├── agentic_opd_env.py      # Agentic OPD environment
└── web_research_env.py     # Web research environment
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| SWE tasks | hermes_swe_env/ | Software engineering challenges |
| Terminal testing | terminal_test_env/ | Terminal interaction testing |
| Model parsers | tool_call_parsers/ | Different parser implementations |
| Benchmarks | benchmarks/ | Evaluation suites |
| Web research | web_research_env.py | Research task environment |

## CONVENTIONS
- Environment implementations follow standard gym-like interfaces
- Parser implementations support different model formats
- Benchmark environments have standardized evaluation protocols

## ANTI-PATTERNS (THIS PROJECT)
- DO NOT hardcode environment-specific behavior in core agent

## UNIQUE STYLES
- Model-specific tool call parsing
- Standardized benchmark evaluation framework
- Terminal-based environment simulation

## COMMANDS
```bash
# Run environments tests
python -m pytest tests/environments/ -v
```

## NOTES
- Environments support Atropos RL training
- Different parsers for different LLM vendors
- Benchmark suite supports multiple evaluation protocols