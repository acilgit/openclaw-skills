#!/bin/bash
#
# task.sh — 任务管理脚本
# 用法: task.sh <command> [options]
#

TASKS_DIR="/root/.openclaw/workspace/data/tasks"
mkdir -p "$TASKS_DIR"

get_task_file() {
    local agent="$1"
    local chat_id="$2"
    echo "${TASKS_DIR}/${agent}@${chat_id}.jsonl"
}

# 添加任务
add_task() {
    local agent="$1"
    local chat_id="$2"
    local task_text="$3"
    local sender_id="${4:-}"
    local sender_name="${5:-}"
    
    local file=$(get_task_file "$agent" "$chat_id")
    local task_id=$(date +%s%N)
    local created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # 群聊时 sender 可为空（用于记录但不筛选）
    local sender_info=""
    if [[ -n "$sender_id" ]]; then
        sender_info=",\"sender_id\":\"$sender_id\""
        [[ -n "$sender_name" ]] && sender_info="${sender_info},\"sender_name\":\"$sender_name\""
    fi
    
    local task_json=$(cat << EOF
{"id":"${task_id}","chat_id":"${chat_id}","task":"${task_text}"${sender_info},"status":"pending","created":"${created}"}
EOF
)
    
    echo "$task_json" >> "$file"
    echo "✅ 任务已添加 [#${task_id}]: ${task_text}"
}

# 列出任务
list_tasks() {
    local agent="$1"
    local chat_id="$2"
    local status="${3:-}"  # optional filter: pending/done
    
    local file=$(get_task_file "$agent" "$chat_id")
    
    if [[ ! -f "$file" ]]; then
        echo "(暂无任务)"
        return 0
    fi
    
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        
        # 按 status 过滤（如果指定了）
        if [[ -n "$status" ]]; then
            local task_status=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
            [[ "$task_status" != "$status" ]] && continue
        fi
        
        local id=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
        local task=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('task',''))" 2>/dev/null)
        local task_status=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
        local sender_name=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sender_name','?'))" 2>/dev/null)
        local created=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('created','')[:10])" 2>/dev/null)
        
        local icon="⭕"
        [[ "$task_status" == "done" ]] && icon="✅"
        
        echo "${icon} [#${id}] ${task}"
        [[ -n "$sender_name" && "$sender_name" != "?" ]] && echo "   👤 ${sender_name} · ${created}"
        count=$((count + 1))
    done < "$file"
    
    if [[ $count -eq 0 ]]; then
        echo "(暂无${status:+ $status }任务)"
    fi
}

# 完成任务
done_task() {
    local agent="$1"
    local chat_id="$2"
    local task_id="$3"
    
    local file=$(get_task_file "$agent" "$chat_id")
    local tmp=$(mktemp)
    
    local found=false
    while IFS= read -r line; do
        [[ -z "$line" ]] && echo "$line" >> "$tmp" && continue
        
        local id=$(echo "$line" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
        
        if [[ "$id" == "$task_id" ]]; then
            # 更新状态
            local updated=$(echo "$line" | python3 -c "import sys,json; d=json.load(sys.stdin); d['status']='done'; d['completed']='$(date -u +%Y-%m-%dT%H:%M:%SZ)'; print(json.dumps(d, ensure_ascii=False))" 2>/dev/null)
            echo "$updated" >> "$tmp"
            found=true
        else
            echo "$line" >> "$tmp"
        fi
    done < "$file"
    
    mv "$tmp" "$file"
    
    if $found; then
        echo "✅ 任务 #${task_id} 已完成"
    else
        echo "❌ 未找到任务 #${task_id}"
    fi
}

# 主入口
case "$1" in
    add)
        add_task "$2" "$3" "$4" "$5" "$6"
        ;;
    list)
        list_tasks "$2" "$3" "$4"
        ;;
    pending)
        list_tasks "$2" "$3" "pending"
        ;;
    done)
        done_task "$2" "$3" "$4"
        ;;
    *)
        echo "用法: task.sh <add|list|pending|done> [options]"
        echo ""
        echo "  task.sh add <agent> <chat_id> '<task>' [sender_id] [sender_name]"
        echo "  task.sh list <agent> <chat_id>           # 列出所有任务"
        echo "  task.sh pending <agent> <chat_id>        # 只列出待完成"
        echo "  task.sh done <agent> <chat_id> <task_id>"
        exit 1
        ;;
esac
