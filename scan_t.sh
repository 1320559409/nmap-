#!/bin/bash
# 通用TCP端口扫描脚本（支持IPv4和IPv6）
# 用法: ./scan_t.sh <ipv4|ipv6>

set -u  # 只检查未定义变量，不自动退出

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

# 权限检查
if [ "$EUID" -ne 0 ]; then
    echo "错误: 需要 root 权限运行（nmap -sS）" >&2
    exit 1
fi

DATE=${SCAN_DATE:-$(date +%Y%m%d-%H)}
OUT_DIR="$DATE"
mkdir -p "$OUT_DIR"

# 根据IP版本设置文件路径
if [ "$IP_VERSION" = "ipv4" ]; then
    IP_FILE="ipv4.conf"
    PORT_FILE="tcp.conf"
    OUTPUT="$OUT_DIR/ipv4_t.gnmap"
else
    IP_FILE="ipv6.conf"
    PORT_FILE="tcp.conf"
    OUTPUT="$OUT_DIR/ipv6_t.gnmap"
fi

# 输入文件验证
if [ ! -f "$IP_FILE" ]; then
    echo "错误: $IP_FILE 文件不存在" >&2
    exit 1
fi

if [ ! -s "$IP_FILE" ]; then
    echo "错误: $IP_FILE 文件为空" >&2
    exit 1
fi

if [ ! -f "$PORT_FILE" ]; then
    echo "错误: $PORT_FILE 文件不存在" >&2
    exit 1
fi

# 解析端口列表
TCP_PORTS=$(awk '{print $1}' "$PORT_FILE" | grep -E '^[0-9]+$' | tr '\n' ',' | sed 's/,$//')
if [ -z "$TCP_PORTS" ]; then
    echo "错误: $PORT_FILE 中没有有效端口号" >&2
    exit 1
fi

TOTAL_IPS=$(wc -l < "$IP_FILE" | tr -d ' ')
PORT_COUNT=$(echo "$TCP_PORTS" | tr ',' '\n' | wc -l)

echo "========================================="
echo "${IP_VERSION^^} TCP 端口扫描"
echo "目标 IP 数: $TOTAL_IPS"
echo "端口数: $PORT_COUNT"
echo "参数: 无主机超时"
echo "========================================="

# 执行扫描
if [ "$IP_VERSION" = "ipv6" ]; then
    nmap -6 -sS -Pn -n -v --stats-every 6s --randomize-hosts \
         --defeat-rst-ratelimit \
         -p "$TCP_PORTS" -iL "$IP_FILE" -oG "$OUTPUT.raw" 2>&1
    mv "$OUTPUT.raw" "$OUTPUT" 2>/dev/null || true
else
    nmap -sS -Pn -n -v --stats-every 6s --randomize-hosts \
         --defeat-rst-ratelimit \
         -p "$TCP_PORTS" -iL "$IP_FILE" -oG "$OUTPUT.raw" 2>&1
    mv "$OUTPUT.raw" "$OUTPUT" 2>/dev/null || true
fi

if [ -f "$OUTPUT" ] && [ -s "$OUTPUT" ]; then
    echo "完成: $OUTPUT"
else
    echo "警告: 未发现开放端口，创建空文件" >&2
    touch "$OUTPUT"
fi
