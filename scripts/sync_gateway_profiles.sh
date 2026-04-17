#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_ROOT="$ROOT_DIR/templates/gateway-profiles"
PROFILES_ROOT="${HERMES_PROFILES_ROOT:-${HOME}/.hermes/profiles}"
ALL_PROFILES=(hermes doubao codecraft flora frontmaster reviewpilot router)

usage() {
    echo "用法: $0 [profile ...]"
    echo ""
    echo "同步指定的 Hermes gateway profile（不传参数则同步全部）。"
    echo ""
    echo "可用的 profile: ${ALL_PROFILES[*]}"
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

if [ $# -gt 0 ]; then
    PROFILES=("$@")
    for p in "${PROFILES[@]}"; do
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
    PROFILES=("${ALL_PROFILES[@]}")
fi

if [ ! -d "$TEMPLATE_ROOT" ]; then
    echo "错误: 未找到 profile 模板目录: $TEMPLATE_ROOT" >&2
    exit 1
fi

mkdir -p "$PROFILES_ROOT"

for profile in "${PROFILES[@]}"; do
    src_dir="$TEMPLATE_ROOT/$profile"
    dst_dir="$PROFILES_ROOT/$profile"

    if [ ! -d "$src_dir" ]; then
        echo "错误: 缺少模板目录: $src_dir" >&2
        exit 1
    fi

    mkdir -p "$dst_dir"
    install -m 600 "$src_dir/config.yaml" "$dst_dir/config.yaml"
    install -m 600 "$src_dir/SOUL.md" "$dst_dir/SOUL.md"

    if [ -f "$src_dir/.env" ]; then
        install -m 600 "$src_dir/.env" "$dst_dir/.env"
    fi

    if [ -f "$src_dir/.env.example" ]; then
        install -m 600 "$src_dir/.env.example" "$dst_dir/.env.example"
    fi

    if [ -d "$src_dir/skills" ]; then
        rm -rf "$dst_dir/skills"
        cp -R "$src_dir/skills" "$dst_dir/skills"
        find "$dst_dir/skills" -type f -exec chmod 600 {} +
    fi

    echo "已同步 profile: $profile -> $dst_dir"
done

echo "同步完成。运行时状态保留在 ${PROFILES_ROOT}/* 下。"
