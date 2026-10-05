# Hourly VPS health check for Hermes cron (--no-agent): prints only when
# something is wrong, and empty output keeps the job silent.

failed=$(systemctl --failed --no-legend --plain | awk '{print $1}')
[ -n "$failed" ] && echo "failed units: $(echo $failed)"

disk=$(df --output=pcent / | tail -1 | tr -dc '0-9')
[ "$disk" -ge 85 ] && echo "root disk at ${disk}%"

mem=$(free | awk '/^Mem:/ {printf "%d", ($2 - $7) * 100 / $2}')
[ "$mem" -ge 90 ] && echo "memory at ${mem}%"

true
