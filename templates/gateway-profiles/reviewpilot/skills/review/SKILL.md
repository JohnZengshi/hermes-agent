---
name: review
description: Run targeted historical code review by git user and date range. Usage: /review <git-username> <start-date> <end-date>
---

# /review 命令技能

该技能用于 Telegram 命令：

`/review <git-username> <start-date> <end-date>`

例如：

- `/review alice 2026-04-01 2026-04-07`
- `/review bob 2026-03-01 2026-03-31`

## 参数解析

将用户输入按空格拆分为 3 个参数：

1. `git_username`
2. `start_date`（建议 YYYY-MM-DD）
3. `end_date`（建议 YYYY-MM-DD）

若参数不足或格式不合法，直接返回简洁错误与正确示例，不执行审查。

## 远程仓库与凭据来源（记忆优先）

按以下优先级取值：

1. **持久记忆（首选）**：owner 在 Telegram 对话中告知并要求“记住”

建议记忆字段（可用自然语言表达，不要求 JSON）：

- 主仓库 URL（例如：`http://git.xxx.com/org/repo.git`）
- Git 拉取账号（用户名）
- Git 拉取凭据（密码或 token）
- 可选额外 `.gitmodules` 路径

若存在多条冲突记忆，以**最近一次 owner 明确指定**为准。

## 执行步骤

1. 先解析运行参数（`main_repo_url` / `git_username` / `git_password` / `extra_gitmodules_file`）：

   - 优先使用当前会话里 owner 明确给出的值
   - 其次使用已注入上下文的持久记忆

   若 `main_repo_url` 或 Git 凭据仍缺失：
   - 返回一条简短缺参提示（仅对 owner）
   - 给出可直接复制的初始化模板
   - 不执行审查

2. 在临时目录准备远程审查工作区（仅拉取，不改动业务仓库），并注入 Git 账号：

```bash
mkdir -p /tmp/reviewpilot-remote
cd /tmp/reviewpilot-remote
rm -rf main-repo

# 将当前解析出的凭据注入本次命令环境
export REVIEW_GIT_USERNAME="${git_username}"
export REVIEW_GIT_PASSWORD="${git_password}"

# 使用凭据拉取私有仓库
cat > /tmp/reviewpilot-git-askpass.sh <<'EOF'
#!/usr/bin/env sh
printf '%s' "$REVIEW_GIT_PASSWORD"
EOF
chmod 700 /tmp/reviewpilot-git-askpass.sh
export GIT_ASKPASS=/tmp/reviewpilot-git-askpass.sh

if [ -z "${REVIEW_GIT_USERNAME}" ] || [ -z "${REVIEW_GIT_PASSWORD}" ]; then
  echo "缺少 Git 凭据（REVIEW_GIT_USERNAME / REVIEW_GIT_PASSWORD）" >&2
  exit 1
fi

git -c credential.username="${git_username}" clone --filter=blob:none --no-checkout "${main_repo_url}" main-repo
cd main-repo
git checkout -q
```

3. 默认从 `main-repo/.gitmodules` 提取 `url = ...` 列表并加入待审查仓库清单；若存在 `extra_gitmodules_file`，再额外合并该文件中的仓库列表。

4. 对清单内每个远程仓库执行历史检索（仅查询，不改动代码）：

```bash
git log --since="<start_date> 00:00:00" --until="<end_date> 23:59:59" --author="<git_username>" --pretty=format:"%H|%an|%ad|%s" --date=iso
```

5. 若所有仓库都没有匹配提交，返回“该时间窗口无匹配提交”。

6. 若有匹配提交：
   - 提取提交列表
   - 对关键提交执行差异查看（如 `git show --stat <sha>`，必要时 `git show <sha>`）
   - 明确每条证据来自哪个远程仓库（repo 标识 + commit hash）
   - 形成结构化审查：
     - 结论（通过/有条件通过/阻塞）
     - 🔴 阻塞问题
     - 🟡 建议优化
     - 💭 可选改进
     - 证据（提交哈希、文件、关键变更）
     - 下一步动作

7. 最终输出首行必须包含提醒文本：`${REVIEW_MENTION_HANDLES}`。

8. 使用 `send_message` 主动推送审查摘要到审查群：
   - platform: `telegram`
   - chat_id: 优先从 `${TELEGRAM_REVIEW_GROUP_IDS}`（逗号分隔）逐个发送；若为空则回退 `${TELEGRAM_REVIEW_GROUP_ID}`
   - thread_id: `${TELEGRAM_REVIEW_THREAD_ID}`（若为空则不传）
   - content: 使用你的最终审查结论（含提醒对象）

9. 在回答末尾附带一句可转发摘要，便于运营方直接复制到群组。

10. 当 owner 提供或更新仓库/凭据信息并明确要求“记住”时，使用 `memory` 工具持久化：
   - `memory(action="add|replace", target="memory", content=...)`
   - 若旧信息变化，优先 `replace`，避免重复脏记忆。

## owner 初始化话术（可复制）

“记住以下审查配置：
主仓库：<repo-url>
Git 账号：<username>
Git 凭据：<password-or-token>
（可选）额外 gitmodules：<path>
后续 /review 默认使用这套配置。”

## 约束

- 不得编造提交或 diff 内容。
- 不得泄露任何密钥/凭据。
- 不进行与审查无关的闲聊。
