#!/bin/bash
cd "$(dirname "$0")"

DATE=${SCAN_DATE:-$(date +%Y%m%d-%H)}
OUT_DIR="$DATE"

SERVICE_FILES=(
    "$OUT_DIR/svc_ipv4_t"
    "$OUT_DIR/svc_ipv6_t"
    "$OUT_DIR/svc_ipv4_u"
    "$OUT_DIR/svc_ipv6_u"
)

TEMP_FILE="$OUT_DIR/.process_temp_$$"
FINAL="$OUT_DIR/final"

trap 'rm -f "$TEMP_FILE"' EXIT INT TERM

for file in "${SERVICE_FILES[@]}"; do
    if [ -f "$file" ] && [ -s "$file" ]; then
        cat "$file" >> "$TEMP_FILE"
    fi
done

if [ ! -s "$TEMP_FILE" ]; then
    echo "警告: 没有发现任何服务记录，输出空文件" >&2
    touch "$FINAL"
    exit 0
fi

sort -u "$TEMP_FILE" | awk 'BEGIN {
    for (i = 0; i <= 9; i++) hex[sprintf("%d", i)] = i
    hex["a"] = 10; hex["b"] = 11; hex["c"] = 12
    hex["d"] = 13; hex["e"] = 14; hex["f"] = 15
}
function hex2dec(h,    val, i, c) {
    val = 0
    h = tolower(h)
    for (i = 1; i <= length(h); i++) {
        c = substr(h, i, 1)
        val = val * 16 + hex[c]
    }
    return val
}
{
    if (index($1, ":") > 0) {
        addr = tolower($1)
        if (index(addr, "::") > 0) {
            split(addr, parts, "::")
            left = parts[1]
            right = parts[2]
            n_left = (left == "") ? 0 : split(left, l_arr, ":")
            n_right = (right == "") ? 0 : split(right, r_arr, ":")
            n_missing = 8 - n_left - n_right
            full = ""
            for (i = 1; i <= n_left; i++) {
                full = full sprintf("%04x:", hex2dec(l_arr[i]))
            }
            for (i = 1; i <= n_missing; i++) {
                full = full "0000:"
            }
            for (i = 1; i <= n_right; i++) {
                full = full sprintf("%04x", hex2dec(r_arr[i]))
                if (i < n_right) full = full ":"
            }
            $1 = tolower(full)
        } else {
            n = split(addr, segs, ":")
            full = ""
            for (i = 1; i <= n; i++) {
                full = full sprintf("%04x", hex2dec(segs[i]))
                if (i < n) full = full ":"
            }
            $1 = tolower(full)
        }
    }
    print
}' OFS='\t' | { echo -e "HOST\tPORT\tPROTO\tSTATE\tSERVICE"; cat; } | column -t -s $'\t' > "$FINAL"

# 显示对齐的预览
echo "完成: $FINAL (共 $(($(wc -l < "$FINAL") - 1)) 条记录)"
echo "前5行预览："
head -5 "$FINAL"
