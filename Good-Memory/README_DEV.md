# Good-Memory — Developer Guide

> Technical reference for integrating and using Good-Memory

---

## Overview

Good-Memory is an OpenClaw skill that provides two capabilities:

1. **Session recovery** — restore conversation context after `/new`
2. **Task management** — track tasks per agent + chat

---

## Quick Start

### 1. Install the skill

```bash
cp -r good-memory ~/.openclaw/skills/good-memory
```

### 2. Integrate session recovery into AGENTS.md

Add this step to the agent's startup sequence:

```markdown
6. **Restore session memory**: Call `sessions_list` (limit=1), get the `transcriptPath` from the result, and read that file directly to restore the most recent 100 messages.
```

### 3. Done

The agent will now automatically restore conversation history on `/new`.

---

## Part 1: Session Recovery

### How it works

```
Agent starts (or /new resets session)
        ↓
Agent calls sessions_list (limit=1)
        ↓
sessions_list returns transcriptPath (points to current session file)
        ↓
Agent reads that file directly
        ↓
Most recent 100 messages are restored
```

### Why sessions_list?

The `transcriptPath` returned by OpenClaw's `sessions_list` tool is managed by OpenClaw itself — it always points to the exact session file for the current agent + chat combination. No guessing, no grep matching, no cross-contamination.

### Manual exploration (optional)

If you want to manually explore sessions for any agent + chat combination, use `recovery.sh`:

```bash
# Scan for session files
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh scan <agent> <chat_id>

# Read messages
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh read <agent> <chat_id> --lines 50

# List file paths only
bash ~/.openclaw/skills/good-memory/scripts/recovery.sh list <agent> <chat_id>
```

---

## Part 2: Task Management

### Problem it solves

In a multi-agent setup, tasks from different chats get mixed together. task.sh solves this by storing tasks in separate files per agent + chat.

### File location

```
~/.openclaw/workspace/data/tasks/<agent>@<chat_id>.jsonl
```

Example:
```
data/tasks/main@ou_1f6214a01a49a1a28b8400628b0ef392.jsonl  # private chat
data/tasks/guwen@oc_5c241ca3df35f46e36bc608d139afe02.jsonl # group chat
```

### Task format

```jsonl
{"id":"1774501644123456789","chat_id":"oc_xxx","task":"Download reports","sender_id":"ou_yyy","sender_name":"Alice","status":"pending","created":"2026-03-26T13:00:00Z"}
{"id":"1774501644123456790","chat_id":"oc_xxx","task":"Generate summary","sender_id":"ou_zzz","sender_name":"Bob","status":"done","created":"2026-03-26T12:00:00Z","completed":"2026-03-26T14:00:00Z"}
```

### Commands

```bash
# Add a task
bash ~/.openclaw/skills/good-memory/scripts/task.sh add <agent> <chat_id> '<task>' [sender_id] [sender_name]

# List all tasks
bash ~/.openclaw/skills/good-memory/scripts/task.sh list <agent> <chat_id>

# List pending tasks only
bash ~/.openclaw/skills/good-memory/scripts/task.sh pending <agent> <chat_id>

# Mark task as done
bash ~/.openclaw/skills/good-memory/scripts/task.sh done <agent> <chat_id> <task_id>
```

### Design note

In group chats, the `sender` is **recorded but not filtered**. This means:
- Everyone in the group can see who assigned each task
- Anyone can pick up an incomplete task left by another member
- Tasks are **not** filtered by sender — all tasks for that chat are visible to all members

This is intentional for hand-off scenarios: if Alice starts a task but can't finish, Bob can see it and continue.

---

## File Structure

```
good-memory/
├── README.md           # User guide (what to expect as an end user)
├── README_DEV.md      # This file (technical integration guide)
├── README_CN.md       # Chinese version
├── SKILL.md           # OpenClaw skill metadata
├── LICENSE            # MIT
└── scripts/
    ├── recovery.sh    # Session recovery
    └── task.sh        # Task management
```

---

## Requirements

- bash
- python3 (for JSON parsing)
- grep, tail, date, awk (standard GNU utilities)
- OpenClaw agents with session files at `~/.openclaw/agents/<agent>/sessions/`

---

## Session File Format

OpenClaw session files use NDJSON (newline-delimited JSON):

| Field | Description |
|-------|-------------|
| `type` | Record type: `session`, `message`, `custom`, `model_change` |
| `timestamp` | ISO 8601 UTC |
| `message.role` | `user` or `assistant` |
| `message.content` | Content array (text, tool calls, etc.) |

---

## License

MIT
