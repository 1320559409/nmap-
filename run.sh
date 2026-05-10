
#!/bin/bash
cd "$(dirname "$0")"

# 加载公共库
if [ -f ./net.sh ]; then
    . ./net.sh
    init_network
else
    echo "错误: net.sh 文件不存在" >&2
    exit 1
fi

# 固定扫描日期+小时，避免跨天/跨小时运行时目录不一致
export SCAN_DATE=$(date +%Y%m%d-%H)
echo "扫描任务日期: $SCAN_DATE"

# 检查必要的配置文件是否存在
for config_file in ipv4.conf ipv6.conf tcp.conf udp.conf; do
    if [ ! -f "$config_file" ]; then
        echo "错误: 配置文件 $config_file 不存在" >&2
        exit 1
    fi
done

# ==================== 第一阶段：端口扫描 ====================
echo ""
echo "========================================="
echo "  第一阶段：端口扫描"
echo "========================================="
echo ""

echo "[1/4] TCP IPv4 端口扫描"
recover_network
# 验证IPv4是否真正可用
if ! check_ipv4; then
    echo "错误: IPv4未恢复，无法继续扫描" >&2
    exit 1
fi
sleep 2  # 等待网络稳定
if [ -f ./scan_t.sh ]; then
    chmod +x ./scan_t.sh
    ./scan_t.sh ipv4
    if [ $? -ne 0 ]; then
        echo "错误: TCP IPv4 端口扫描失败" >&2
        exit 1
    fi
else
    echo "错误: scan_t.sh 文件不存在" >&2
    exit 1
fi

echo "[2/4] TCP IPv6 端口扫描"
recover_network
if [ -f ./scan_t.sh ]; then
    chmod +x ./scan_t.sh
    ./scan_t.sh ipv6
    if [ $? -ne 0 ]; then
        echo "错误: TCP IPv6 端口扫描失败" >&2
        exit 1
    fi
else
    echo "错误: scan_t.sh 文件不存在" >&2
    exit 1
fi

echo "[3/4] UDP IPv4 端口扫描"
recover_network
# 验证IPv4是否真正可用
if ! check_ipv4; then
    echo "错误: IPv4未恢复，无法继续扫描" >&2
    exit 1
fi
sleep 2  # 等待网络稳定
if [ -f ./scan_u.sh ]; then
    chmod +x ./scan_u.sh
    ./scan_u.sh ipv4
    if [ $? -ne 0 ]; then
        echo "错误: UDP IPv4 端口扫描失败" >&2
        exit 1
    fi
else
    echo "错误: scan_u.sh 文件不存在" >&2
    exit 1
fi

echo "[4/4] UDP IPv6 端口扫描"
recover_network
if [ -f ./scan_u.sh ]; then
    chmod +x ./scan_u.sh
    ./scan_u.sh ipv6
    if [ $? -ne 0 ]; then
        echo "错误: UDP IPv6 端口扫描失败" >&2
        exit 1
    fi
else
    echo "错误: scan_u.sh 文件不存在" >&2
    exit 1
fi

echo ""
echo "========================================="
echo "  第一阶段完成"
echo "========================================="
echo ""

# ==================== 第二阶段：服务探测 ====================
echo ""
echo "========================================="
echo "  第二阶段：服务探测"
echo "========================================="
echo ""

echo "[1/4] TCP IPv4 服务探测"
recover_network
# 验证IPv4是否真正可用
if ! check_ipv4; then
    echo "警告: IPv4未恢复，跳过TCP IPv4服务探测" >&2
else
    sleep 2  # 等待网络稳定
    if [ -f ./svc_t.sh ]; then
        chmod +x ./svc_t.sh
        ./svc_t.sh ipv4
        if [ $? -ne 0 ]; then
            echo "警告: TCP IPv4 服务探测失败" >&2
        fi
    else
        echo "错误: svc_t.sh 文件不存在" >&2
    fi
fi

echo "[2/4] TCP IPv6 服务探测"
recover_network
if [ -f ./svc_t.sh ]; then
    chmod +x ./svc_t.sh
    ./svc_t.sh ipv6
    if [ $? -ne 0 ]; then
        echo "警告: TCP IPv6 服务探测失败" >&2
    fi
else
    echo "错误: svc_t.sh 文件不存在" >&2
fi

echo "[3/4] UDP IPv4 服务探测"
recover_network
# 验证IPv4是否真正可用
if ! check_ipv4; then
    echo "警告: IPv4未恢复，跳过UDP IPv4服务探测" >&2
else
    sleep 2  # 等待网络稳定
    if [ -f ./svc_u.sh ]; then
        chmod +x ./svc_u.sh
        ./svc_u.sh ipv4
        if [ $? -ne 0 ]; then
            echo "警告: UDP IPv4 服务探测失败" >&2
        fi
    else
        echo "错误: svc_u.sh 文件不存在" >&2
    fi
fi

echo "[4/4] UDP IPv6 服务探测"
recover_network
if [ -f ./svc_u.sh ]; then
    chmod +x ./svc_u.sh
    ./svc_u.sh ipv6
    if [ $? -ne 0 ]; then
        echo "警告: UDP IPv6 服务探测失败" >&2
    fi
else
    echo "错误: svc_u.sh 文件不存在" >&2
fi

echo ""
echo "========================================="
echo "  第二阶段完成"
echo "========================================="
echo ""

# ==================== 第三阶段：结果合并 ====================
echo ""
echo "========================================="
echo "  第三阶段：结果合并"
echo "========================================="
echo ""

echo "合并所有扫描结果..."
if [ -f ./final.sh ]; then
    chmod +x ./final.sh
    ./final.sh
    if [ $? -ne 0 ]; then
        echo "错误: 结果合并失败" >&2
        exit 1
    fi
else
    echo "错误: final.sh 文件不存在" >&2
    exit 1
fi

echo ""
echo "========================================="
echo "  全部完成！"
echo "  最终结果: $SCAN_DATE/final"
echo "========================================="
echo ""

# 扫描结束后恢复网络
echo "恢复网络状态..."
recover_network
echo ""
