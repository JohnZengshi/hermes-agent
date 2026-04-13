#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_ROOT="$ROOT_DIR/templates/gateway-profiles"
PROFILES_ROOT="${HOME}/.hermes/profiles"
PROFILES=(hermes doubao codecraft flora router)

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

    echo "已同步 profile: $profile -> $dst_dir"
done

echo "同步完成。运行时状态仍保留在 ~/.hermes/profiles/* 下。"
