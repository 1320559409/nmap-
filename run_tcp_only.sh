#!/bin/bash
set -e
cd "$(dirname "$0")"

recover_ipv4() {
    if ip -4 addr show eth0 | grep -q 'inet '; then
        echo "    [OK] IPv4 normal: $(ip -4 addr show eth0 | grep 'inet ' | awk '{print $2}')" >&2
        return 0
    fi

    echo "    [WARN] IPv4 lost! Recovering with nmcli..." >&2
    
    nmcli device reapply eth0 2>/dev/null && sleep 2
    
    if ! ip -4 addr show eth0 | grep -q 'inet '; then
        echo "    [WARN] nmcli failed, trying dhclient..." >&2
        dhclient -r eth0 2>/dev/null || true
        sleep 1
        dhclient eth0
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

echo "========== TCP IPv4 Port Scan =========="
./port_tcp4

echo "========== TCP IPv6 Port Scan =========="
./port_tcp6
recover_ipv4

echo "========== TCP IPv4 Service Probe =========="
./service_tcp4

echo "========== TCP IPv6 Service Probe =========="
./service_tcp6
recover_ipv4

echo "========== Merge all existing results (TCP+UDP) =========="
./process

echo "TCP scan finished. Final result is in service_all.txt"

