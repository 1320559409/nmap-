#!/bin/bash
set -e
cd "$(dirname "$0")"

# 固定扫描日期，避免跨天运行时目录不一致
export SCAN_DATE=$(date +%Y%m%d)
echo "扫描任务日期: $SCAN_DATE"

recover_ipv4() {
    if ip -4 addr show eth0 | grep -q 'inet '; then
        echo "    [OK] IPv4 normal: $(ip -4 addr show eth0 | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    fi

    echo "    [WARN] IPv4 lost! Recovering with nmcli..." >&2
    
    nmcli device reapply eth0 2>/dev/null && sleep 2
    
    if ! ip -4 addr show eth0 | grep -q 'inet '; then
        echo "    [WARN] nmcli reapply failed, trying connection restart..." >&2
        nmcli connection down eth0 2>/dev/null || true
        sleep 1
        nmcli connection up eth0
        sleep 5
    fi

    if ip -4 addr show eth0 | grep -q 'inet '; then
        echo "    [OK] Recovered: $(ip -4 addr show eth0 | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    else
        echo "    [FATAL] Cannot recover IPv4!" >&2
        exit 1
    fi
}

reset_network() {
    echo "    [INFO] Checking and resetting network interface..." >&2
     
    # 暴力断开连接
    nmcli device disconnect eth0 2>/dev/null || true
    sleep 5
    
    # 重新连接
    nmcli device connect eth0 2>/dev/null || true
    sleep 10

    # 检查 IPv4 是否恢复
    if ip -4 addr show eth0 | grep -q 'inet '; then
        echo "    [OK] Network reset successful: $(ip -4 addr show eth0 | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    fi
    
    # 如果失败，重启 NetworkManager
    echo "    [WARN] Device reconnect failed, restarting NetworkManager..." >&2
    systemctl restart NetworkManager 2>/dev/null || true
    sleep 15

    if ip -4 addr show eth0 | grep -q 'inet '; then
        echo "    [OK] Network recovered: $(ip -4 addr show eth0 | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    else
        echo "    [FATAL] Cannot recover IPv4!" >&2
        ip -4 addr show eth0 >&2
        exit 1
    fi
}

echo "========== UDP IPv4 Port Scan =========="
reset_network
./port_udp4

echo "========== UDP IPv6 Port Scan =========="
./port_udp6
recover_ipv4

echo "========== UDP IPv4 Service Probe =========="
./service_udp4

echo "========== UDP IPv6 Service Probe =========="
./service_udp6
recover_ipv4

echo "========== Merge all existing results (TCP+UDP) =========="
./process

echo "UDP scan finished. Final result is in service_all"


