# Good-Memory

> 🧠 OpenClaw Agent 会话历史恢复 & 多 Agent 任务管理

本 Skill 包含两个工具：

1. **recovery.sh** — /new 后还原对话上下文
2. **task.sh** — 按 agent+chat 隔离追踪任务

---

## 第一部分：会话恢复（recovery.sh）

### 两种恢复方式

有两种方式可以恢复会话历史。**方式 A** 用于 Agent 启动恢复（精确），**方式 B** 用于手动探索。

#### 方式 A：sessions_list 工具（/new 恢复推荐用这个）

这是 **正确** 的 Agent 启动集成方式。使用 OpenClaw 的 `sessions_list` 工具返回精确的 `transcriptPath`——无需猜测，无交叉污染。

**在 AGENTS.md 中集成：**

```markdown
6. **恢复会话记忆**：调用 `sessions_list` 工具（limit=1），从返回结果中获取 `transcriptPath`，直接读取该文件还原最近 100 条消息历史。

   每个 Agent 只能读取自己的 session，transcriptPath 在 Agent + 聊天组合下是唯一的，不会读取到其他 Agent 或其他聊天的记录。
```

**工作流程：**
1. Agent 调用 `sessions_list`（limit=1）
2. 从返回结果提取 `transcriptPath`（如 `/root/.openclaw/agents/main/sessions/abc123.jsonl`）
3. 直接读取该特定文件
4. 解析并显示最近的消息

**为什么这种方式可靠：**
- `transcriptPath` 由 OpenClaw 自身管理——它始终指向 Agent 的当前 session
- 不涉及文件名匹配或内容 grep
- 100% 精确，无假阳性

#### 方式 B：recovery.sh scan/read（手动探索用）

当你想要手动查找任意 agent + chat 组合的 session 时使用。它通过 grep 匹配在文件内容中搜索 `chat_id`。

**局限性：** 此方法在消息内容中搜索 `chat_id`，意味着：
- 如果 chat_id 出现在不同 session 的消息文本中，可能返回假阳性
- 无法区分"当前 session"和"归档 session"
- 如需可靠恢复，请使用方式 A

**命令：**

```bash
# scan — 查找包含此 chat_id 的 session 文件（不可靠，仅用于探索）
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh scan <agent> <chat_id>

# read — 从特定 session 文件读取消息
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh read <agent> <chat_id> [选项]

# list — 仅显示文件路径
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh list <agent> <chat_id>
```

**示例：**
```bash
# 探索该 agent+chat 有哪些 session
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh scan main ou_1f6214a01a49a1a28b8400628b0ef392

# 从这些 session 读取最近 20 条消息
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh read main ou_1f6214a01a49a1a28b8400628b0ef392 --lines 20
```

---

## 第二部分：任务管理（task.sh）

### 解决什么问题

在多 Agent 架构中，不同用户或群组向不同 Agent 分配任务时，所有任务混在一个共享列表里。无法知道：
- 哪些任务属于哪个 Agent
- 哪些任务属于哪个聊天（群组 vs 单聊）
- 谁分配了每个任务（在群聊中，方便交接）

**task.sh** 通过维护独立的 agent+chat 任务文件来解决这个问题。

### 任务文件位置

```
~/.openclaw/workspace/data/tasks/<agent>@<chat_id>.jsonl
```

### 任务数据格式

```jsonl
{"id":"1774501644123456789","chat_id":"oc_xxx","task":"下载EMSD文件","sender_id":"ou_yyy","sender_name":"张三","status":"pending","created":"2026-03-26T13:00:00Z"}
{"id":"1774501644123456790","chat_id":"oc_xxx","task":"生成日报","sender_id":"ou_zzz","sender_name":"李四","status":"done","created":"2026-03-26T12:00:00Z","completed":"2026-03-26T14:00:00Z"}
```

### 使用方法

```bash
bash ~/.openclaw/skills/good-memory/scripts/task.sh <命令> [选项]
```

| 命令 | 说明 |
|------|------|
| `add <agent> <chat_id> '<任务>' [sender_id] [sender_name]` | 添加任务 |
| `list <agent> <chat_id>` | 列出所有任务 |
| `pending <agent> <chat_id>` | 只列出待完成任务 |
| `done <agent> <chat_id> <task_id>` | 完成任务 |

**示例：**
```bash
# 群聊 — 记录发送者（方便交接）
bash ~/.openclaw/skills/good-memory/scripts/task.sh add guwen oc_5c241ca3df35f46e36bc608d139afe02 "下载EMSD报告" "ou_xxx" "张三"

# 单聊 — 通常省略发送者
bash ~/.openclaw/skills/good-memory/scripts/task.sh add main ou_1f6214a01a49a1a28b8400628b0ef392 "构建演示文稿"

# 列出任务
bash ~/.openclaw/skills/good-memory/scripts/task.sh list guwen oc_5c241ca3df35f46e36bc608d139afe02

# 标记完成
bash ~/.openclaw/skills/good-memory/scripts/task.sh done guwen oc_5c241ca3df35f46e36bc608d139afe02 1774501644123456789
```

**输出：**
```
⭕ [#1774501644123456789] 下载EMSD报告
   👤 张三 · 2026-03-26
✅ [#1774501644123456790] 生成日报
   👤 李四 · 2026-03-25
```

---

## Session 文件格式

OpenClaw session 文件使用 NDJSON（换行分隔的 JSON）。每行是一个 JSON 对象：

| 字段 | 说明 |
|------|------|
| `type` | 记录类型：`session`、`message`、`custom`、`model_change` 等 |
| `timestamp` | ISO 8601 UTC 时间戳 |
| `message.role` | `user` 或 `assistant` |
| `message.content` | 消息内容数组（文本、工具调用等） |

---

## 安装

```bash
# 复制 skill 到 OpenClaw skills 目录
cp -r good-memory ~/.openclaw/skills/good-memory

# data/tasks/ 目录会在首次使用时自动创建
```

## 文件结构

```
good-memory/
├── README.md           # 英文文档
├── README_CN.md       # 本文档（中文）
├── SKILL.md           # OpenClaw skill 元数据
├── LICENSE            # MIT 许可证
└── scripts/
    ├── recovery.sh    # 会话历史恢复
    └── task.sh        # 任务管理
```

## 环境要求

- bash
- python3（用于 JSON 解析）
- grep、tail、date、awk（标准 GNU 工具）
- OpenClaw Agent，session 文件位于 `~/.openclaw/agents/<agent>/sessions/`

## 许可证

MIT — 自由使用，任意修改。

---

*隶属于 [OpenClaw](https://github.com/openclaw/openclaw) 生态。*
