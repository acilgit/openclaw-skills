# Good-Memory — User Guide

> 🧠 For OpenClaw agents that have this skill installed

---

## What it does automatically

### Session Memory Restoration

When you start a **new conversation** with an agent (via `/new`), Good-Memory **automatically restores** the previous conversation's context. The agent will know what you discussed before.

- **No manual action needed** — this happens automatically
- Each agent only restores its **own** conversation history (not other agents' chats)
- Works for both **group chats** and **private chats**

---

## What you can ask the agent to do

### Task Management

You can ask the agent to manage tasks for you. Tasks are stored **per chat**, so tasks from different group chats don't mix.

**Add a task:**
```
Add a task: remind me to submit the report tomorrow
```

**List all tasks:**
```
Show me my pending tasks
```

**Complete a task:**
```
Mark task #12345 as done
```

(Replace `12345` with the actual task ID shown in the task list)

---

## If you're setting up a new agent

If you're installing Good-Memory into an agent that doesn't have it yet:

1. **Copy the skill files** to the agent's skills directory:
   ```
   cp -r good-memory ~/.openclaw/skills/good-memory/
   ```

2. **Add session recovery to AGENTS.md** — add this step to the agent's startup sequence:
   ```
   6. Call `sessions_list` (limit=1), get the `transcriptPath`, read that file to restore the last 100 messages.
   ```

That's it. After these two steps, the agent will automatically restore conversation history on `/new`.

---

## For Developers

See [README_DEV.md](README_DEV.md) for integration details, skill installation, and command reference.
