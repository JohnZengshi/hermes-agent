#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_PATH="$ROOT_DIR/venv/bin/python"
SYNC_SCRIPT="$ROOT_DIR/scripts/sync_gateway_profiles.sh"
LOG_DIR="$ROOT_DIR/logs"
PROFILES_ROOT="${HOME}/.hermes/profiles"

if [ ! -f "$PYTHON_PATH" ]; then
    echo "错误: 未找到虚拟环境的 Python: $PYTHON_PATH" >&2
    exit 1
fi

if [ ! -x "$SYNC_SCRIPT" ]; then
    echo "错误: 未找到可执行同步脚本: $SYNC_SCRIPT" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

"$SYNC_SCRIPT"

read_env_value() {
    "$PYTHON_PATH" - "$1" "$2" <<'PY'
from pathlib import Path
import sys
from dotenv import dotenv_values

values = dotenv_values(Path(sys.argv[1]))
value = values.get(sys.argv[2], "")
print("" if value is None else str(value), end="")
PY
}

validate_profile_env() {
    local profile="$1"
    shift
    local env_file="$PROFILES_ROOT/$profile/.env"

    if [ ! -f "$env_file" ]; then
        echo "错误: 缺少 ${env_file}。请先填写 templates/gateway-profiles/${profile}/.env。" >&2
        exit 1
    fi

    for var_name in "$@"; do
        local current_value
        current_value="$(read_env_value "$env_file" "$var_name")"
        if [ -z "$current_value" ]; then
            echo "错误: ${env_file} 缺少 ${var_name}。请先填写 templates/gateway-profiles/${profile}/.env。" >&2
            exit 1
        fi
    done
}

validate_matching_backend_key() {
    local backend_profile="$1"
    local router_var_name="$2"
    local backend_env_file="$PROFILES_ROOT/$backend_profile/.env"
    local router_env_file="$PROFILES_ROOT/router/.env"
    local backend_key
    local router_key

    backend_key="$(read_env_value "$backend_env_file" API_KEY)"
    router_key="$(read_env_value "$router_env_file" "$router_var_name")"

    if [ "$backend_key" != "$router_key" ]; then
        echo "错误: router/.env 中的 ${router_var_name} 与 ${backend_profile}/.env 中的 API_KEY 不一致。" >&2
        exit 1
    fi
}

validate_profile_env hermes API_KEY
validate_profile_env doubao API_KEY OPENCODE_GO_API_KEY
validate_profile_env codecraft API_KEY OPENCODE_GO_API_KEY
validate_profile_env router ROUTER_API_KEY HERMES_BACKEND_API_KEY DOUBAO_BACKEND_API_KEY CODECRAFT_BACKEND_API_KEY

validate_matching_backend_key hermes HERMES_BACKEND_API_KEY
validate_matching_backend_key doubao DOUBAO_BACKEND_API_KEY
validate_matching_backend_key codecraft CODECRAFT_BACKEND_API_KEY

for profile in hermes doubao codecraft router; do
    pkill -f "hermes_cli.main -p $profile gateway run" 2>/dev/null || true
done
sleep 2

echo "正在启动 Hermes 网关进程..."

start_gateway() {
    local profile="$1"
    local log_file="$LOG_DIR/$profile.log"
    HERMES_HOME="$PROFILES_ROOT/$profile" "$PYTHON_PATH" -m hermes_cli.main -p "$profile" gateway run --replace -v > "$log_file" 2>&1 &
    local pid=$!
    echo "$profile:$pid"
}

HERMES_RESULT="$(start_gateway hermes)"
HERMES_PID="${HERMES_RESULT#*:}"
sleep 3

DOUBAO_RESULT="$(start_gateway doubao)"
DOUBAO_PID="${DOUBAO_RESULT#*:}"
sleep 3

CODECRAFT_RESULT="$(start_gateway codecraft)"
CODECRAFT_PID="${CODECRAFT_RESULT#*:}"
sleep 3

ROUTER_RESULT="$(start_gateway router)"
ROUTER_PID="${ROUTER_RESULT#*:}"

echo "所有进程已启动:"
echo "Hermes PID: $HERMES_PID"
echo "Doubao PID: $DOUBAO_PID"
echo "CodeCraft PID: $CODECRAFT_PID"
echo "Router PID: $ROUTER_PID"
echo "日志已输出至 $LOG_DIR/ 目录"
