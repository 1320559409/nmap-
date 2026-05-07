#!/bin/bash
echo "测试 uports 文件解析..."
echo "=== 原始内容 ==="
cat -A uports | head -5
echo ""
echo "=== awk 提取第一列 ==="
awk '{print $1}' uports | head -5 | cat -A
echo ""
echo "=== grep 过滤数字 ==="
awk '{print $1}' uports | grep -E '^[0-9]+$' | head -5 | cat -A
echo ""
echo "=== 最终结果 ==="
UDP_PORTS=$(awk '{print $1}' uports | grep -E '^[0-9]+$' | tr '\n' ',' | sed 's/,$//')
echo "UDP_PORTS='$UDP_PORTS'"
if [ -z "$UDP_PORTS" ]; then
    echo "错误: UDP_PORTS 为空!"
else
    echo "成功! 端口数: $(echo "$UDP_PORTS" | tr ',' '\n' | wc -l)"
fi

