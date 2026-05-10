# gnmap parser
/^Host:/ {
    if (match($0, /Host:[[:space:]]+([0-9a-fA-F.:]+)/)) {
        ip = substr($0, RSTART+6, RLENGTH-6)
        gsub(/[[:space:]]/, "", ip)
    }
    
    if (match($0, /Ports: /)) {
        rest = substr($0, RSTART + 7)
        split(rest, entries, ",")
        for (i in entries) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", entries[i])
            if (entries[i] == "") continue
            
            n = split(entries[i], parts, "/")
            if (n >= 5) {
                port_num = parts[1]
                state = parts[2]
                protocol = parts[3]
                owner = parts[4]
                service = parts[5]
                
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", service)
                
                if (state == "open") {
                    if (service == "") service = "unknown"
                    printf "%s\t%s\t%s\t%s\t%s\n", ip, port_num, protocol, state, service
                }
            }
        }
    }
}
