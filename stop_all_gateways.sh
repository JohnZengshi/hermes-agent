#!/bin/bash

set -euo pipefail

profiles=(hermes doubao codecraft flora frontmaster reviewpilot router)
stopped_any=false

echo "正在停止 Hermes 网关进程..."

for profile in "${profiles[@]}"; do
    if pkill -f "hermes_cli.main -p $profile gateway run" 2>/dev/null; then
        echo "已停止 $profile 网关"
        stopped_any=true
    else
        echo "$profile 网关未运行"
    fi
done

if [ "$stopped_any" = true ]; then
    echo "所有匹配的网关进程已发送停止信号。"
else
    echo "没有发现需要停止的网关进程。"
fi
