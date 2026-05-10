#!/bin/bash
# 网络管理公共函数库 - 适用于Kali环境

# 自动检测默认网络接口
detect_network_interface() {
    local iface
    iface=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')
    if [ -z "$iface" ]; then
        # 尝试IPv6路由
        iface=$(ip -6 route show default 2>/dev/null | awk '{print $5; exit}')
    fi
    if [ -z "$iface" ]; then
        #  fallback: 查找第一个UP状态的接口（排除lo）
        iface=$(ip link show state up 2>/dev/null | awk -F': ' '/^[0-9]+:/ && !/lo/ {print $2; exit}' | cut -d@ -f1)
    fi
    echo "${iface:-eth0}"
}

# 检查IPv4是否可用
check_ipv4() {
    local iface="${1:-$NETWORK_INTERFACE}"
    if ip -4 addr show "$iface" 2>/dev/null | grep -q 'inet '; then
        return 0
    else
        return 1
    fi
}

# 检查IPv6是否真正可用（有全局地址且有路由）
check_ipv6() {
    local iface="${1:-$NETWORK_INTERFACE}"
    # 检查是否有全局IPv6地址
    if ! ip -6 addr show "$iface" 2>/dev/null | grep -q 'inet6.*global'; then
        return 1
    fi
    # 检查IPv6路由是否可达
    if ! ip -6 route get 2001:4860:4860::8888 >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# 温和的网络恢复（优先使用reapply）
recover_network() {
    local iface="${1:-$NETWORK_INTERFACE}"
    
    # 先检查IPv4是否正常
    if check_ipv4 "$iface"; then
        echo "    [OK] IPv4 normal: $(ip -4 addr show "$iface" | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    fi

    echo "    [WARN] IPv4 lost! Attempting recovery..." >&2
    
    # 方法1: nmcli reapply（最温和）
    if command -v nmcli >/dev/null 2>&1; then
        nmcli device reapply "$iface" 2>/dev/null && sleep 1
        
        if check_ipv4 "$iface"; then
            echo "    [OK] Recovered via reapply: $(ip -4 addr show "$iface" | grep 'inet ' | awk '{print $2}')" >&2
            return 0
        fi
        
        # 方法2: nmcli断开重连（更可靠）
        echo "    [WARN] Reapply failed, trying device reconnect..." >&2
        nmcli device disconnect "$iface" 2>/dev/null || true
        sleep 5
        nmcli device connect "$iface" 2>/dev/null || true
        sleep 10
        
        if check_ipv4 "$iface"; then
            echo "    [OK] Recovered via nmcli reconnect: $(ip -4 addr show "$iface" | grep 'inet ' | awk '{print $2}')" >&2
            return 0
        fi
    fi
    
    # 方法3: 重启NetworkManager服务
    echo "    [WARN] Device reconnect failed, restarting NetworkManager..." >&2
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart NetworkManager 2>/dev/null || true
        sleep 15
    fi

    if check_ipv4 "$iface"; then
        echo "    [OK] Recovered via NetworkManager restart: $(ip -4 addr show "$iface" | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    fi
    
    # 不再尝试更多方法，避免完全断网
    echo "    [FATAL] Cannot recover IPv4 after all attempts!" >&2
    ip -4 addr show "$iface" >&2
    return 1
}

# 强制重置网络（您要求的：每次扫描前断开重连）
reset_network() {
    local iface="${1:-$NETWORK_INTERFACE}"
    
    echo "    [INFO] Force resetting network interface $iface..." >&2
     
    # 使用nmcli断开重连
    if command -v nmcli >/dev/null 2>&1; then
        nmcli device disconnect "$iface" 2>/dev/null || true
        sleep 5
        
        # 重新连接
        nmcli device connect "$iface" 2>/dev/null || true
        sleep 10
    else
        echo "    [ERROR] nmcli not available, cannot reset network" >&2
        return 1
    fi

    # 检查 IPv4 是否恢复
    if check_ipv4 "$iface"; then
        echo "    [OK] Network reset successful: $(ip -4 addr show "$iface" | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    fi
    
    # 如果失败，重启 NetworkManager
    echo "    [WARN] Device reconnect failed, restarting NetworkManager..." >&2
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart NetworkManager 2>/dev/null || true
        sleep 15
    fi

    if check_ipv4 "$iface"; then
        echo "    [OK] Network recovered: $(ip -4 addr show "$iface" | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    else
        echo "    [FATAL] Cannot recover IPv4!" >&2
        ip -4 addr show "$iface" >&2
        return 1
    fi
}

# 初始化网络接口（在所有脚本开头调用）
init_network() {
    # 自动检测网络接口（除非已设置）
    if [ -z "${NETWORK_INTERFACE:-}" ]; then
        export NETWORK_INTERFACE=$(detect_network_interface)
        echo "[INFO] Detected network interface: $NETWORK_INTERFACE" >&2
    fi
}
