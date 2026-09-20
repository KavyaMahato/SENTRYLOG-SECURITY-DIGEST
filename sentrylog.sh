#!/bin/bash
REPORT="/var/log/sentrylog/security_report_$(date +%F).txt"
mkdir -p /var/log/sentrylog

echo "=== Failed Authentication Attempts ===" > "$REPORT"
journalctl --since "24 hours ago" | grep -E "Failed password|authentication failure" >> "$REPORT"

echo "=== Service Failures ===" >> "$REPORT"
journalctl --since "24 hours ago" | grep -E "failed|Failed" >> "$REPORT"

echo "=== Priority err or above ===" >> "$REPORT"
journalctl -p err --since "24 hours ago" >> "$REPORT"

declare -A ipcount
while read -r line; do
    ip=$(echo "$line" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}")
    [ -n "$ip" ] && ipcount["$ip"]=$((${ipcount["$ip"]:-0}+1))
done < <(grep "Failed password" "$REPORT")

echo "=== IP Failure Counts ===" >> "$REPORT"
for ip in "${!ipcount[@]}"; do
    count=${ipcount[$ip]}
    if [ "$count" -gt 5 ]; then
        echo "$ip: $count attempts - SUSPECT" >> "$REPORT"
    else
        echo "$ip: $count attempts" >> "$REPORT"
    fi
done
