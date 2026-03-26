---
name: good-memory
description: Session 历史恢复 & 多 Agent 任务管理 Skill。包含两个工具：(1) recovery.sh — 通过 sessions_list 工具恢复会话历史；(2) task.sh — 按 agent+chat 隔离的任务管理。用于 /new 后快速恢复对话上下文，以及多 Agent 协作中的任务追踪。
homepage: https://github.com/openclaw/openclaw
metadata: {"openclaw":{"emoji":"🧠","requires":{"bins":["bash","grep","tail","date","awk"]}}}
---

# Good-Memory

包含两个核心工具：

1. **recovery.sh** — Session 历史恢复（/new 后还原对话）
2. **task.sh** — 多 Agent 任务管理（按 agent+chat 隔离追踪）

## recovery.sh

### 恢复方式

**方式 A（推荐）：sessions_list 工具**

用于 Agent 启动恢复，精确可靠：

```bash
# 在 AGENTS.md 第6步集成：
# 调用 sessions_list (limit=1)，获取 transcriptPath，直接读取文件
```

**方式 B：scan/read 命令**

用于手动探索（不可靠，不建议用于恢复）：

```bash
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh scan <agent> <chat_id>
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh read <agent> <chat_id> [--lines N]
```

## task.sh

### 命令列表

| 命令 | 说明 |
|------|------|
| `task.sh add <agent> <chat_id> '<task>' [sender_id] [sender_name]` | 添加任务 |
| `task.sh list <agent> <chat_id>` | 列出所有任务 |
| `task.sh pending <agent> <chat_id>` | 只列出待完成任务 |
| `task.sh done <agent> <chat_id> <task_id>` | 完成任务 |

### 任务文件存储

每个 agent-chat 组合有独立文件：
```
~/.openclaw/workspace/data/tasks/<agent>@<chat_id>.jsonl
```

### 任务数据格式

```jsonl
{"id":"1774501644123456789","chat_id":"oc_xxx","task":"下载EMSD文件","sender_id":"ou_yyy","sender_name":"李四","status":"pending","created":"2026-03-26T13:00:00Z"}
{"id":"1774501644123456790","chat_id":"oc_xxx","task":"生成日报","sender_id":"ou_zzz","sender_name":"王五","status":"done","created":"2026-03-26T12:00:00Z","completed":"2026-03-26T14:00:00Z"}
```
