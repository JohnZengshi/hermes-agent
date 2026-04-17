#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_PATH="$ROOT_DIR/venv/bin/python"
SYNC_SCRIPT="$ROOT_DIR/scripts/sync_gateway_profiles.sh"
SETUP_DOCKER_MAC_SCRIPT="$ROOT_DIR/scripts/setup_docker_sandbox_mac.sh"
SETUP_DOCKER_LINUX_SCRIPT="$ROOT_DIR/scripts/setup_docker_sandbox_linux.sh"
LOG_DIR="$ROOT_DIR/logs"
PROFILES_ROOT="${HOME}/.hermes/profiles"

ensure_docker_ready() {
    # 仅在检测到 Docker backend 被启用时做就绪检查。
    # macOS + Colima: 若 daemon 未启动则自动拉起。
    # 其他平台: 仅做可用性校验，失败时给出明确错误。
    local docker_required="false"
    local profile
    local cfg

    for profile in hermes doubao codecraft flora frontmaster reviewpilot router; do
        cfg="$PROFILES_ROOT/$profile/config.yaml"
        if [ ! -f "$cfg" ]; then
            continue
        fi
        if grep -Eq '^\s*backend:\s*docker\s*$' "$cfg"; then
            docker_required="true"
            break
        fi
    done

    if [ "$docker_required" != "true" ]; then
        return 0
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "错误: 检测到 profile 使用 terminal.backend=docker，但未安装 docker CLI。" >&2
        echo "请先安装 Docker/Colima，或将对应 profile 改为非 docker backend。" >&2
        exit 1
    fi

    if docker info >/dev/null 2>&1; then
        return 0
    fi

    local os_name
    os_name="$(uname -s)"

    if [ "$os_name" = "Darwin" ]; then
        if [ ! -f "$SETUP_DOCKER_MAC_SCRIPT" ]; then
            echo "错误: 缺少 mac Docker 沙箱脚本: $SETUP_DOCKER_MAC_SCRIPT" >&2
            exit 1
        fi
        echo "检测到 Docker daemon 未就绪，正在执行脚本: $SETUP_DOCKER_MAC_SCRIPT"
        bash "$SETUP_DOCKER_MAC_SCRIPT"
    elif [ "$os_name" = "Linux" ]; then
        if [ ! -f "$SETUP_DOCKER_LINUX_SCRIPT" ]; then
            echo "错误: 缺少 Linux Docker 沙箱脚本: $SETUP_DOCKER_LINUX_SCRIPT" >&2
            exit 1
        fi
        if [ "${EUID:-$(id -u)}" -ne 0 ]; then
            echo "检测到 Docker daemon 未就绪，Linux 初始化脚本需要 root 权限。" >&2
            echo "请执行: sudo bash $SETUP_DOCKER_LINUX_SCRIPT" >&2
            echo "完成后重新运行: ./start_all_gateways.sh" >&2
            exit 1
        fi
        echo "检测到 Docker daemon 未就绪，正在执行脚本: $SETUP_DOCKER_LINUX_SCRIPT"
        bash "$SETUP_DOCKER_LINUX_SCRIPT"
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "错误: Docker daemon 不可用，且自动启动失败。" >&2
        if [ "$os_name" = "Darwin" ]; then
            echo "请手动执行: bash $SETUP_DOCKER_MAC_SCRIPT" >&2
        elif [ "$os_name" = "Linux" ]; then
            echo "请手动执行: sudo bash $SETUP_DOCKER_LINUX_SCRIPT" >&2
        fi
        exit 1
    fi
}

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

ensure_docker_ready

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
validate_profile_env codecraft API_KEY CODECRAFT_BASE_URL THIRD_PARTY_API_KEY
validate_profile_env flora API_KEY OPENCODE_GO_API_KEY
validate_profile_env frontmaster API_KEY FRONTMASTER_BASE_URL THIRD_PARTY_API_KEY
validate_profile_env reviewpilot API_KEY TELEGRAM_BOT_TOKEN TELEGRAM_ALLOWED_USERS TELEGRAM_REVIEW_GROUP_ID WEBHOOK_GLOBAL_SECRET REVIEW_PUSH_ROUTE_SECRET
validate_profile_env router ROUTER_API_KEY HERMES_BACKEND_API_KEY DOUBAO_BACKEND_API_KEY CODECRAFT_BACKEND_API_KEY FLORA_BACKEND_API_KEY FRONTMASTER_BACKEND_API_KEY REVIEWPILOT_BACKEND_API_KEY

validate_matching_backend_key hermes HERMES_BACKEND_API_KEY
validate_matching_backend_key doubao DOUBAO_BACKEND_API_KEY
validate_matching_backend_key codecraft CODECRAFT_BACKEND_API_KEY
validate_matching_backend_key flora FLORA_BACKEND_API_KEY
validate_matching_backend_key frontmaster FRONTMASTER_BACKEND_API_KEY
validate_matching_backend_key reviewpilot REVIEWPILOT_BACKEND_API_KEY

for profile in hermes doubao codecraft flora frontmaster reviewpilot router; do
    pkill -f "hermes_cli.main -p $profile gateway run" 2>/dev/null || true
done
sleep 2

echo "正在启动 Hermes 网关进程..."

start_gateway() {
    local profile="$1"
    local log_file="$LOG_DIR/$profile.log"
    local env_file="$PROFILES_ROOT/$profile/.env"
    local terminal_cwd=""
    local messaging_cwd=""

    if [ -f "$env_file" ]; then
        terminal_cwd="$(read_env_value "$env_file" "TERMINAL_CWD")"
        messaging_cwd="$(read_env_value "$env_file" "MESSAGING_CWD")"
    fi

    if [ -z "$terminal_cwd" ]; then
        terminal_cwd="$messaging_cwd"
    fi

    if [ -n "$terminal_cwd" ]; then
        HERMES_HOME="$PROFILES_ROOT/$profile" MESSAGING_CWD="$messaging_cwd" TERMINAL_CWD="$terminal_cwd" "$PYTHON_PATH" -m hermes_cli.main -p "$profile" gateway run --replace -v > "$log_file" 2>&1 &
    elif [ -n "$messaging_cwd" ]; then
        HERMES_HOME="$PROFILES_ROOT/$profile" MESSAGING_CWD="$messaging_cwd" "$PYTHON_PATH" -m hermes_cli.main -p "$profile" gateway run --replace -v > "$log_file" 2>&1 &
    else
        HERMES_HOME="$PROFILES_ROOT/$profile" "$PYTHON_PATH" -m hermes_cli.main -p "$profile" gateway run --replace -v > "$log_file" 2>&1 &
    fi
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

FLORA_RESULT="$(start_gateway flora)"
FLORA_PID="${FLORA_RESULT#*:}"
sleep 3

FRONTMASTER_RESULT="$(start_gateway frontmaster)"
FRONTMASTER_PID="${FRONTMASTER_RESULT#*:}"
sleep 3

REVIEWPILOT_RESULT="$(start_gateway reviewpilot)"
REVIEWPILOT_PID="${REVIEWPILOT_RESULT#*:}"
sleep 3

ROUTER_RESULT="$(start_gateway router)"
ROUTER_PID="${ROUTER_RESULT#*:}"

echo "所有进程已启动:"
echo "Hermes PID: $HERMES_PID"
echo "Doubao PID: $DOUBAO_PID"
echo "CodeCraft PID: $CODECRAFT_PID"
echo "Flora PID: $FLORA_PID"
echo "FrontMaster PID: $FRONTMASTER_PID"
echo "ReviewPilot PID: $REVIEWPILOT_PID"
echo "Router PID: $ROUTER_PID"
echo "日志已输出至 $LOG_DIR/ 目录"
