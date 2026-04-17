#!/usr/bin/env bash

set -euo pipefail

# Linux 一键准备 Hermes Docker 沙箱（优先 rootless）
# 用法：
#   bash scripts/setup_docker_sandbox_linux.sh
# 可选变量：
#   ROOTLESS=true|false            (默认 true)
#   TARGET_USER=<username>         (默认当前用户)
#   HERMES_SANDBOX_WORKSPACE=...   (默认 /opt/hermes/workspace)

ROOTLESS="${ROOTLESS:-true}"
TARGET_USER="${TARGET_USER:-$(id -un)}"
WORKSPACE_DIR="${HERMES_SANDBOX_WORKSPACE:-/opt/hermes/workspace}"
DOCKER_READY_TIMEOUT="${DOCKER_READY_TIMEOUT:-60}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "错误: 该脚本需要 root 执行（用于安装依赖与配置用户）" >&2
  echo "请使用: sudo bash scripts/setup_docker_sandbox_linux.sh" >&2
  exit 1
fi

if ! id "${TARGET_USER}" >/dev/null 2>&1; then
  echo "错误: 用户不存在: ${TARGET_USER}" >&2
  exit 1
fi

has_cmd() { command -v "$1" >/dev/null 2>&1; }

wait_for_rootful_docker() {
  local timeout="$1"
  local interval=2
  local elapsed=0

  while ! docker info >/dev/null 2>&1; do
    if [[ "${elapsed}" -ge "${timeout}" ]]; then
      echo "错误: rootful Docker 在 ${timeout} 秒内仍未就绪。" >&2
      return 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
}

rootless_docker_ready() {
  local user="$1"
  su - "${user}" -c 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock; docker info >/dev/null 2>&1'
}

wait_for_rootless_docker() {
  local user="$1"
  local timeout="$2"
  local interval=2
  local elapsed=0

  while ! rootless_docker_ready "${user}"; do
    if [[ "${elapsed}" -ge "${timeout}" ]]; then
      echo "错误: 用户 ${user} 的 rootless Docker 在 ${timeout} 秒内仍未就绪。" >&2
      echo "请切换到该用户后执行: docker info" >&2
      return 1
    fi
    sleep "${interval}"
    elapsed=$((elapsed + interval))
  done
}

install_prereqs() {
  if has_cmd apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y uidmap dbus-user-session slirp4netns fuse-overlayfs curl ca-certificates
  elif has_cmd dnf; then
    dnf install -y shadow-utils dbus-daemon slirp4netns fuse-overlayfs curl ca-certificates
  elif has_cmd yum; then
    yum install -y shadow-utils dbus-daemon slirp4netns fuse-overlayfs curl ca-certificates
  else
    echo "错误: 不支持的发行版（未找到 apt-get/dnf/yum）" >&2
    exit 1
  fi
}

ensure_subid() {
  local user="$1"
  if ! grep -qE "^${user}:" /etc/subuid; then
    echo "${user}:100000:65536" >> /etc/subuid
  fi
  if ! grep -qE "^${user}:" /etc/subgid; then
    echo "${user}:100000:65536" >> /etc/subgid
  fi
}

install_docker_if_missing() {
  if has_cmd docker; then
    echo "==> Docker 已安装，跳过安装"
    return
  fi
  echo "==> 安装 Docker Engine"
  curl -fsSL https://get.docker.com | sh
}

setup_rootless_for_user() {
  local user="$1"
  local user_home
  user_home="$(eval echo "~${user}")"

  ensure_subid "${user}"

  echo "==> 为用户 ${user} 配置 rootless Docker"
  su - "${user}" -c 'dockerd-rootless-setuptool.sh install'

  # 允许用户级 systemd 服务在退出后保持运行
  if has_cmd loginctl; then
    loginctl enable-linger "${user}" || true
  fi

  # 写入 shell 环境变量
  local profile_file="${user_home}/.profile"
  touch "${profile_file}"
  if ! grep -q "DOCKER_HOST=unix:///run/user/" "${profile_file}"; then
    cat >> "${profile_file}" <<'EOF'

# Rootless Docker (Hermes sandbox)
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock
EOF
  fi

  echo "==> 启动用户 ${user} 的 rootless Docker 服务"
  su - "${user}" -c 'export XDG_RUNTIME_DIR=/run/user/$(id -u); export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus; systemctl --user daemon-reload || true; systemctl --user enable --now docker || true'

  echo "==> 等待用户 ${user} 的 rootless Docker 就绪"
  wait_for_rootless_docker "${user}" "${DOCKER_READY_TIMEOUT}"
}

setup_rootful_for_user() {
  local user="$1"
  echo "==> 使用 rootful Docker（将用户加入 docker 组）"
  usermod -aG docker "${user}"
  systemctl enable --now docker
  echo "==> 等待 rootful Docker 就绪"
  wait_for_rootful_docker "${DOCKER_READY_TIMEOUT}"
}

echo "==> 安装依赖"
install_prereqs

echo "==> 安装 Docker"
install_docker_if_missing

if [[ "${ROOTLESS}" == "true" ]]; then
  setup_rootless_for_user "${TARGET_USER}"
else
  setup_rootful_for_user "${TARGET_USER}"
fi

echo "==> 创建 Hermes 沙箱工作目录: ${WORKSPACE_DIR}"
mkdir -p "${WORKSPACE_DIR}"
chown -R "${TARGET_USER}:${TARGET_USER}" "${WORKSPACE_DIR}"

cat <<EOF

✅ Linux 沙箱环境准备完成（Docker 已可用）

模式: $( [[ "${ROOTLESS}" == "true" ]] && echo "rootless" || echo "rootful" )
目标用户: ${TARGET_USER}
工作目录: ${WORKSPACE_DIR}

建议 codecraft profile 的 terminal 配置：
  backend: docker
  cwd: /workspace
  docker_volumes:
    - ${WORKSPACE_DIR}:/workspace

下一步：
1) 切换到目标用户: su - ${TARGET_USER}
2) 如为 rootless 模式，首次登录后可再执行一次 docker info 确认环境变量已生效
3) 回到项目执行: ./start_all_gateways.sh

已支持环境变量覆盖：
  ROOTLESS / TARGET_USER / HERMES_SANDBOX_WORKSPACE / DOCKER_READY_TIMEOUT
EOF
