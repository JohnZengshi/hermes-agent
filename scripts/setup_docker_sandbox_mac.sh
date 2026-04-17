#!/bin/bash

set -euo pipefail

wait_for_docker() {
  local timeout="${DOCKER_READY_TIMEOUT:-60}"
  local interval=2
  local elapsed=0

  while ! docker info >/dev/null 2>&1; do
    if [ "${elapsed}" -ge "${timeout}" ]; then
      echo "错误: Docker daemon 在 ${timeout} 秒内仍未就绪（当前 context: $(docker context show 2>/dev/null || echo unknown)）。" >&2
      exit 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
}

echo "==> 检查 Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "错误: 未检测到 Homebrew。请先安装: https://brew.sh/" >&2
  exit 1
fi

echo "==> 安装 Colima + Docker CLI"
brew install colima docker docker-buildx docker-compose

CPU="${COLIMA_CPU:-4}"
MEMORY="${COLIMA_MEMORY:-8}"
DISK="${COLIMA_DISK:-80}"

if colima status >/dev/null 2>&1; then
  echo "==> Colima 已运行，跳过 start"
else
  echo "==> 启动 Colima (cpu=${CPU}, memory=${MEMORY}GiB, disk=${DISK}GiB)"
  colima start --cpu "${CPU}" --memory "${MEMORY}" --disk "${DISK}" --runtime docker
fi

echo "==> 切换 Docker context 到 colima"
docker context use colima

echo "==> 等待 Docker daemon 就绪"
wait_for_docker

echo "==> 验证 Docker 可用"
docker version >/dev/null
docker info >/dev/null

WORKSPACE_DIR="${HERMES_SANDBOX_WORKSPACE:-/tmp/hermes-workspace}"
echo "==> 创建 Hermes 沙箱工作目录: ${WORKSPACE_DIR}"
mkdir -p "${WORKSPACE_DIR}"

cat <<EOF

✅ mac 沙箱环境就绪（Colima + Docker）

建议在 codecraft profile 中使用以下 terminal 配置：
  backend: docker
  cwd: /workspace
  docker_volumes:
    - ${WORKSPACE_DIR}:/workspace

已支持环境变量覆盖：
  COLIMA_CPU / COLIMA_MEMORY / COLIMA_DISK
  DOCKER_READY_TIMEOUT
  HERMES_SANDBOX_WORKSPACE
EOF
