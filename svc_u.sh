#!/bin/bash
# 通用UDP服务探测脚本（支持IPv4和IPv6）
# 用法: ./svc_u.sh <ipv4|ipv6>
# 特性：断点续扫、动态并发、严格过滤unknown

set -u

cd "$(dirname "$0")"

# 加载公共库
. ./net.sh
init_network

# 参数验证
IP_VERSION="${1:-ipv4}"
if [ "$IP_VERSION" != "ipv4" ] && [ "$IP_VERSION" != "ipv6" ]; then
    echo "错误: 参数必须是 ipv4 或 ipv6" >&2
    exit 1
fi

DATE=${SCAN_DATE:-$(date +%Y%m%d-%H)}
OUT_DIR="$DATE"

# 根据IP版本设置文件路径
if [ "$IP_VERSION" = "ipv4" ]; then
    GNMAP="$OUT_DIR/ipv4_u.gnmap"
    OUTFILE="$OUT_DIR/svc_ipv4_u"
    COMPLETED_FILE="$OUT_DIR/.completed_u_ipv4"
else
    GNMAP="$OUT_DIR/ipv6_u.gnmap"
    OUTFILE="$OUT_DIR/svc_ipv6_u"
    COMPLETED_FILE="$OUT_DIR/.completed_u_ipv6"
fi

TMPDIR_WORK="$OUT_DIR/tmp_u_${IP_VERSION}_$$"

# 检查gnmap文件（端口扫描结果）
if [ ! -f "$GNMAP" ]; then
    echo "警告: $GNMAP 不存在，请先运行端口扫描 (scan_u.sh)" >&2
    touch "$OUTFILE"
    exit 0
fi

# 检查gnmap文件是否为空
if [ ! -s "$GNMAP" ]; then
    echo "警告: $GNMAP 为空，没有发现开放端口" >&2
    touch "$OUTFILE"
    exit 0
fi

mkdir -p "$TMPDIR_WORK"
trap 'rm -rf "$TMPDIR_WORK"' EXIT INT TERM

# 使用 awk 统一解析 gnmap，提取 IP 和端口（每行一个端口）
TASK_FILE_RAW="$TMPDIR_WORK/tasks_raw"
awk '/^Host:/ && /\/open\/udp\// {
    if (match($0, /Host:[[:space:]]+([0-9a-fA-F.:]+)/)) {
        ip = substr($0, RSTART+6, RLENGTH-6)
        gsub(/[[:space:]]/, "", ip)
    }
    if (match($0, /Ports: /)) {
        rest = substr($0, RSTART + 7)
        split(rest, entries, ",")
        for (i in entries) {
            if (match(entries[i], /\/open\/udp\//)) {
                split(entries[i], parts, "/")
                print ip, parts[1]
            }
        }
    }
}' "$GNMAP" | sort -u > "$TASK_FILE_RAW"

# 检查是否有开放的端口
if [ ! -s "$TASK_FILE_RAW" ]; then
    echo "未发现任何开放 UDP 端口" >&2
    touch "$OUTFILE"
    exit 0
fi

# 按 IP 分组端口（格式：IP port1,port2,port3）
TASK_FILE="$TMPDIR_WORK/tasks"
awk '{
    if ($1 in ips) {
        ips[$1] = ips[$1] "," $2
    } else {
        ips[$1] = $2
        order[++count] = $1
    }
}
END {
    for (i = 1; i <= count; i++) {
        print order[i], ips[order[i]]
    }
}' "$TASK_FILE_RAW" > "$TASK_FILE"

TOTAL_IPS=$(wc -l < "$TASK_FILE" | tr -d ' ')
echo "开始 ${IP_VERSION^^} UDP 服务探测，共 $TOTAL_IPS 个 IP" >&2

# 动态计算并发数
CPU_CORES=$(nproc)
JOBS=$(( CPU_CORES * 2 ))
JOBS=$(( JOBS > 20 ? 20 : JOBS ))
JOBS=$(( JOBS > TOTAL_IPS ? TOTAL_IPS : JOBS ))
echo "并发数: $JOBS (CPU: $CPU_CORES, 目标: $TOTAL_IPS)" >&2

# 初始化断点续扫文件
touch "$COMPLETED_FILE"
TEMP_OUTPUT="$TMPDIR_WORK/output_temp"
> "$TEMP_OUTPUT"

# 过滤未完成的 IP
if [ -s "$COMPLETED_FILE" ]; then
    echo "发现断点记录，跳过已完成 IP" >&2
    TASK_REMAINING="$TMPDIR_WORK/tasks_remaining"
    # 使用 awk 精确匹配第一列（避免 grep -F 前缀匹配问题）
    awk 'NR==FNR{ips[$1]; next} !($1 in ips)' "$COMPLETED_FILE" "$TASK_FILE" > "$TASK_REMAINING" || true
    # 如果 awk 没有输出任何行，文件可能为空
    if [ ! -s "$TASK_REMAINING" ]; then
        > "$TASK_REMAINING"
    fi
else
    TASK_REMAINING="$TASK_FILE"
fi

REMAINING_IPS=0
if [ -s "$TASK_REMAINING" ]; then
    REMAINING_IPS=$(wc -l < "$TASK_REMAINING" | tr -d ' ')
fi
if [ "$REMAINING_IPS" -eq 0 ]; then
    echo "所有 IP 已完成扫描，直接合并结果" >&2
else
    echo "待扫描 IP 数: $REMAINING_IPS" >&2
    
    # 使用后台进程并行扫描（Kali/Debian 原生支持）
    echo "开始并行扫描，实时进度如下：" >&2
        
    # 创建临时扫描脚本
    SCAN_SCRIPT="$TMPDIR_WORK/do_scan.sh"
    cat > "$SCAN_SCRIPT" <<SCRIPT_EOF
#!/bin/bash
IP_VERSION="\$1"
TARGET_IP="\$2"
PORTS="\$3"
OUTFILE="\$4"
INDEX="\$5"
if [ "\$IP_VERSION" = "ipv6" ]; then
    nmap -6 -sU -sV -v --version-intensity 8 -Pn -n \
         --stats-every 6s -T3 \
         -p "\$PORTS" "\$TARGET_IP" -oG "\${OUTFILE}.\${INDEX}.raw" 2>&1
    awk -f parse.awk "\${OUTFILE}.\${INDEX}.raw" >> "\${OUTFILE}.\${INDEX}"
    rm -f "\${OUTFILE}.\${INDEX}.raw"
else
    nmap -sU -sV -v --version-intensity 8 -Pn -n \
         --stats-every 6s -T3 \
         -p "\$PORTS" "\$TARGET_IP" -oG "\${OUTFILE}.\${INDEX}.raw" 2>&1
    awk -f parse.awk "\${OUTFILE}.\${INDEX}.raw" >> "\${OUTFILE}.\${INDEX}"
    rm -f "\${OUTFILE}.\${INDEX}.raw"
fi
SCRIPT_EOF
    chmod +x "$SCAN_SCRIPT"
    
    COUNT=0
    TOTAL_REMAINING=$REMAINING_IPS
    while IFS=' ' read -r TARGET_IP PORTS; do
        bash "$SCAN_SCRIPT" "$IP_VERSION" "$TARGET_IP" "$PORTS" "$TEMP_OUTPUT" "$COUNT" &
        COUNT=$((COUNT + 1))
            
        # 显示进度
        if [ $((COUNT % 5)) -eq 0 ] || [ $COUNT -eq $TOTAL_REMAINING ]; then
            echo "    已启动: $COUNT/$TOTAL_REMAINING" >&2
        fi
            
        if [ $((COUNT % JOBS)) -eq 0 ]; then
            wait
            echo "    批次完成: $COUNT/$TOTAL_REMAINING" >&2
        fi
    done < "$TASK_REMAINING"
        
    wait
    echo "    全部扫描完成" >&2
    
    # 合并所有临时输出文件
    if ls "${TEMP_OUTPUT}."* 1>/dev/null 2>&1; then
        cat "${TEMP_OUTPUT}."* > "$TEMP_OUTPUT"
        rm -f "${TEMP_OUTPUT}."*
    fi
    
    # 记录已完成的 IP
    if [ -s "$TASK_REMAINING" ]; then
        awk '{print $1}' "$TASK_REMAINING" >> "$COMPLETED_FILE"
    fi
fi

# 合并结果：覆盖旧记录，保留未重扫的 IP
if [ -s "$OUTFILE" ] && [ -s "$TEMP_OUTPUT" ]; then
    # 提取本次已完成的 IP
    COMPLETED_IPS="$TMPDIR_WORK/completed_ips"
    awk '{print $1}' "$TASK_REMAINING" | sort -u > "$COMPLETED_IPS"
    
    # 从旧文件中排除已完成的 IP，保留未重扫的结果
    awk -F'\t' 'NR==FNR{ips[$1]; next} !($1 in ips)' "$COMPLETED_IPS" "$OUTFILE" > "$OUTFILE.old"
    
    # 合并：旧结果（未重扫的 IP）+ 新结果（本次扫的 IP）
    cat "$OUTFILE.old" "$TEMP_OUTPUT" | sort -u > "$OUTFILE"
    rm -f "$OUTFILE.old"
elif [ -s "$TEMP_OUTPUT" ]; then
    mv "$TEMP_OUTPUT" "$OUTFILE"
fi

FINAL_COUNT=$(wc -l < "$OUTFILE" | tr -d ' ')
echo "完成: $OUTFILE (共 $FINAL_COUNT 条)" >&2
