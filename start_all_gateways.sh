#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_PATH="$ROOT_DIR/venv/bin/python"
SYNC_SCRIPT="$ROOT_DIR/scripts/sync_gateway_profiles.sh"
SETUP_DOCKER_MAC_SCRIPT="$ROOT_DIR/scripts/setup_docker_sandbox_mac.sh"
SETUP_DOCKER_LINUX_SCRIPT="$ROOT_DIR/scripts/setup_docker_sandbox_linux.sh"
LOG_DIR="$ROOT_DIR/logs"

# 加载项目级环境配置（不提交 git）
if [ -f "$ROOT_DIR/.env.local" ]; then
    set -a
    . "$ROOT_DIR/.env.local"
    set +a
fi

PROFILES_ROOT="${HERMES_PROFILES_ROOT:-${HOME}/.hermes/profiles}"

ALL_PROFILES=(hermes doubao codecraft flora frontmaster reviewpilot router)

usage() {
    echo "用法: $0 [profile ...]"
    echo ""
    echo "启动指定的 Hermes 网关 profile（不传参数则启动全部）。"
    echo ""
    echo "可用的 profile: ${ALL_PROFILES[*]}"
    echo ""
    echo "示例:"
    echo "  $0                  # 启动所有 gateway"
    echo "  $0 hermes router    # 只启动 hermes 和 router"
    echo "  $0 codecraft        # 只启动 codecraft"
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

# 确定要启动哪些 profile
if [ $# -gt 0 ]; then
    SELECTED_PROFILES=("$@")
    for p in "${SELECTED_PROFILES[@]}"; do
        found=false
        for valid in "${ALL_PROFILES[@]}"; do
            if [ "$p" = "$valid" ]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            echo "错误: 未知 profile '$p'。可用: ${ALL_PROFILES[*]}" >&2
            exit 1
        fi
    done
else
    SELECTED_PROFILES=("${ALL_PROFILES[@]}")
fi

ensure_docker_ready() {
    # 仅在检测到 Docker backend 被启用时做就绪检查。
    # macOS + Colima: 若 daemon 未启动则自动拉起。
    # 其他平台: 仅做可用性校验，失败时给出明确错误。
    local docker_required="false"
    local profile
    local cfg

    for profile in "${SELECTED_PROFILES[@]}"; do
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

"$SYNC_SCRIPT" "${SELECTED_PROFILES[@]}"

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

# 校验所选 profile 的 .env 文件存在性和 API_KEY
for profile in "${SELECTED_PROFILES[@]}"; do
    env_file="$PROFILES_ROOT/$profile/.env"
    if [ ! -f "$env_file" ]; then
        echo "错误: 缺少 ${env_file}。请先填写 profiles 配置。" >&2
        exit 1
    fi
    api_key="$(read_env_value "$env_file" API_KEY)"
    if [ -z "$api_key" ]; then
        echo "错误: ${env_file} 缺少 API_KEY。" >&2
        exit 1
    fi
done

# 如果选中了 router，校验其路由变量
if [[ " ${SELECTED_PROFILES[*]} " =~ router ]]; then
    router_env_file="$PROFILES_ROOT/router/.env"
    for var in ROUTER_API_KEY HERMES_BACKEND_API_KEY DOUBAO_BACKEND_API_KEY CODECRAFT_BACKEND_API_KEY FLORA_BACKEND_API_KEY; do
        val="$(read_env_value "$router_env_file" "$var")"
        if [ -z "$val" ]; then
            echo "错误: ${router_env_file} 缺少 ${var}。" >&2
            exit 1
        fi
    done
fi

# 校验所选 backend 与 router 的 API_KEY 一致性（仅当 router 和 backend 都在选中列表时）
if [[ " ${SELECTED_PROFILES[*]} " =~ router ]]; then
    router_env_file="$PROFILES_ROOT/router/.env"
    for backend in hermes doubao codecraft flora; do
        if [[ ! " ${SELECTED_PROFILES[*]} " =~ $backend ]]; then
            continue
        fi
        backend_api_key="$(read_env_value "$PROFILES_ROOT/$backend/.env" API_KEY)"
        router_var="HERMES_BACKEND_API_KEY"
        case "$backend" in
            doubao)    router_var="DOUBAO_BACKEND_API_KEY" ;;
            codecraft) router_var="CODECRAFT_BACKEND_API_KEY" ;;
            flora)     router_var="FLORA_BACKEND_API_KEY" ;;
        esac
        router_backend_key="$(read_env_value "$router_env_file" "$router_var")"
        if [ "$backend_api_key" != "$router_backend_key" ]; then
            echo "错误: router/.env 中的 ${router_var} 与 ${backend}/.env 中的 API_KEY 不一致。" >&2
            exit 1
        fi
    done
fi

# 杀掉已选 profile 的旧进程
for profile in "${SELECTED_PROFILES[@]}"; do
    pid_file="$PROFILES_ROOT/$profile/gateway.pid"
    if [ -f "$pid_file" ]; then
        pid=$("$PYTHON_PATH" -c "import json,sys; print(json.load(open(sys.argv[1]))['pid'])" "$pid_file" 2>/dev/null) || true
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    fi
done
sleep 2

echo "正在启动 Hermes 网关进程: ${SELECTED_PROFILES[*]}"

PID_RESULTS=""

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
    if [ -n "$PID_RESULTS" ]; then
        PID_RESULTS="$PID_RESULTS"$'\n'"$profile:$pid"
    else
        PID_RESULTS="$profile:$pid"
    fi
}

prev_profile=""
for profile in "${SELECTED_PROFILES[@]}"; do
    start_gateway "$profile"
    if [ "$prev_profile" != "" ]; then
        sleep 3
    fi
    prev_profile="$profile"
done

echo ""
echo "网关进程已启动:"
while IFS=: read -r name pid; do
    echo "$name PID: $pid"
done <<< "$PID_RESULTS"
echo ""
echo "日志已输出至 $LOG_DIR/ 目录"
