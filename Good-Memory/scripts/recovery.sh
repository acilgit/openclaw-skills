#!/bin/bash
#
# Good-Memory: Session 历史记录恢复脚本
# 用法: recovery.sh <command> [options]
#

set -e

SESSIONS_BASE="/root/.openclaw/agents"
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

error() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }
info() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}WARNING: $1${NC}"; }

# 解析 session 文件的元信息
# 返回: first_time|last_time|total_records|is_active
parse_session_meta() {
    local file="$1"
    local first_time last_time total_records is_active=false

    # 总行数
    total_records=$(wc -l < "$file" 2>/dev/null || echo 0)

    # 首行时间和末行时间
    first_time=$(head -1 "$file" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('timestamp',''))" 2>/dev/null || echo "")
    last_time=$(tail -1 "$file" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('timestamp',''))" 2>/dev/null || echo "")

    # 是否为活跃文件（无 .reset. 或 .deleted. 后缀）
    if [[ "$file" != *.reset.* && "$file" != *.deleted.* ]]; then
        is_active=true
    fi

    echo "${first_time}|${last_time}|${total_records}|${is_active}"
}

# 扫描匹配 chat_id 的 session 文件
# 返回 JSON 数组
scan_sessions() {
    local agent="$1"
    local chat_id="$2"
    local sessions_dir="${SESSIONS_BASE}/${agent}/sessions"

    [[ -d "$sessions_dir" ]] || { echo "[]"; return 0; }

    local result="[]"
    local first=true

    # 遍历所有 .jsonl 文件
    for file in "$sessions_dir"/*.jsonl; do
        [[ -f "$file" ]] || continue

        # 只读前 20 行匹配 chat_id（session key 通常在较前位置出现）
        local matched=false
        for i in {1..20}; do
            line=$(sed -n "${i}p" "$file" 2>/dev/null || echo "")
            [[ -z "$line" ]] && break
            if echo "$line" | grep -q "$chat_id"; then
                matched=true
                break
            fi
        done

        [[ "$matched" != true ]] && continue

        # 解析元信息
        local meta=$(parse_session_meta "$file")
        local first_time=$(echo "$meta" | cut -d'|' -f1)
        local last_time=$(echo "$meta" | cut -d'|' -f2)
        local total_records=$(echo "$meta" | cut -d'|' -f3)
        local is_active=$(echo "$meta" | cut -d'|' -f4)

        local filename=$(basename "$file")
        local path="$file"

        # JSON 输出
        if [[ "$first" == true ]]; then
            first=false
            result="[{\"filename\":\"${filename}\",\"path\":\"${path}\",\"is_active\":${is_active},\"first_time\":\"${first_time}\",\"last_time\":\"${last_time}\",\"total_records\":${total_records}}"
        else
            result="${result},{\"filename\":\"${filename}\",\"path\":\"${path}\",\"is_active\":${is_active},\"first_time\":\"${first_time}\",\"last_time\":\"${last_time}\",\"total_records\":${total_records}}"
        fi
    done

    result="${result}]"
    echo "$result"
}

# 读取 session 记录
read_sessions() {
    local agent="$1"
    local chat_id="$2"
    local lines=10
    local before_time="" after_time=""
    local read_all=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lines)
                lines="$2"; shift 2 ;;
            --before)
                before_time="$2"; shift 2 ;;
            --after)
                after_time="$2"; shift 2 ;;
            --all)
                read_all=true; shift ;;
            *)
                shift ;;
        esac
    done

    # 先扫描文件
    local files_json=$(scan_sessions "$agent" "$chat_id")
    local file_count=$(echo "$files_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

    [[ "$file_count" -eq 0 ]] && { echo "No sessions found for chat_id: $chat_id"; return 0; }

    # 按时间排序（最新的在前）
    local sorted_files=$(echo "$files_json" | python3 -c "
import sys,json
files = json.load(sys.stdin)
files.sort(key=lambda x: x.get('last_time','') or '', reverse=True)
for f in files:
    print(f['path'])
" 2>/dev/null)

    local output_lines=0

    # 读取每个文件
    while IFS= read -r file; do
        [[ -z "$file" || ! -f "$file" ]] && continue

        # 如果是 --all，直接读全部
        if [[ "$read_all" == true ]]; then
            # 输出时加文件名标记
            echo -e "\n=== $(basename "$file") ==="
            while IFS= read -r line; do
                extract_and_print_line "$line" "$before_time" "$after_time" || true
            done < <(cat "$file")
            continue
        fi

        # 按时间范围或条数读取
        while IFS= read -r line; do
            if ! extract_and_print_line "$line" "$before_time" "$after_time"; then
                [[ $? -eq 2 ]] && continue 2  # 已超出时间范围，停止
            fi
            output_lines=$((output_lines + 1))
            [[ $output_lines -ge $lines ]] && return 0
        done < <(cat "$file")
    done <<< "$sorted_files"
}

# 从一行 JSON 提取时间和内容，判断是否输出
extract_and_print_line() {
    local line="$1"
    local before_time="$2"
    local after_time="$3"

    [[ -z "$line" ]] && return 1

    # 提取 timestamp
    local timestamp
    timestamp=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); t=d.get('timestamp',''); print(t if t else '')" 2>/dev/null || echo "")
    [[ -z "$timestamp" ]] && return 0

    # 判断消息类型
    local msg_type
    msg_type=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('type',''))" 2>/dev/null || echo "")

    local display=""
    case "$msg_type" in
        message)
            local msg=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(json.dumps(d.get('message',{})))" 2>/dev/null)
            local role=$(echo "$msg" | python3 -c "import sys,json; m=json.load(sys.stdin); print(m.get('role',''))" 2>/dev/null || echo "")
            local ct=$(echo "$msg" | python3 -c "import sys,json; m=json.load(sys.stdin); print(json.dumps(m.get('content','')))" 2>/dev/null)
            local text=""
            if [[ "$ct" == *"text"* ]]; then
                text=$(echo "$ct" | python3 -c "import sys,json; ct=json.load(sys.stdin); text='';
if isinstance(ct,list):
    for c in ct:
        if isinstance(c,dict) and c.get('type')=='text': text=c.get('text',''); break
elif isinstance(ct,str): text=ct
print(text[:200])" 2>/dev/null || echo "")
            elif [[ "$ct" == *"toolResult"* || "$ct" == *"tool_use"* ]]; then
                text="[tool result]"
            fi
            [[ -n "$text" ]] && display="[${role}] ${text}"
            ;;
        custom)
            local custom_type=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('customType',''))" 2>/dev/null || echo "")
            [[ -n "$custom_type" ]] && display="[${custom_type}]"
            ;;
        *)
            [[ -n "$msg_type" ]] && display="[${msg_type}]"
            ;;
    esac

    [[ -z "$display" ]] && return 0

    # 时间范围过滤
    if [[ -n "$before_time" && "$timestamp" > "$before_time" ]]; then
        return 2  # 超过 before，停止
    fi
    if [[ -n "$after_time" && "$timestamp" < "$after_time" ]]; then
        return 0  # 早于 after，跳过
    fi

    echo "[${timestamp}] ${display}"
    return 0
}

# 列出文件路径
list_sessions() {
    local agent="$1"
    local chat_id="$2"

    local files_json=$(scan_sessions "$agent" "$chat_id")
    local file_count=$(echo "$files_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

    [[ "$file_count" -eq 0 ]] && { echo "No sessions found for chat_id: $chat_id"; return 0; }

    echo "$files_json" | python3 -c "
import sys,json
files = json.load(sys.stdin)
files.sort(key=lambda x: x.get('last_time','') or '', reverse=True)
for f in files:
    print(f['path'])
"
}

# 主入口
main() {
    [[ $# -lt 1 ]] && { echo "Usage: $0 <command> [options]"; echo "Commands: scan, read, list"; exit 1; }

    local command="$1"; shift

    case "$command" in
        scan)
            [[ $# -lt 2 ]] && { echo "Usage: $0 scan <agent> <chat_id>"; exit 1; }
            scan_sessions "$1" "$2"
            ;;
        read)
            [[ $# -lt 2 ]] && { echo "Usage: $0 read <agent> <chat_id> [options]"; exit 1; }
            read_sessions "$@"
            ;;
        list)
            [[ $# -lt 2 ]] && { echo "Usage: $0 list <agent> <chat_id>"; exit 1; }
            list_sessions "$1" "$2"
            ;;
        *)
            echo "Unknown command: $command"
            echo "Commands: scan, read, list"
            exit 1
            ;;
    esac
}

main "$@"
