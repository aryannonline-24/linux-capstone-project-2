#!/bin/bash
# Linux Capstone Project 2 - Aryan Kumar
# Run as root; cron supplies a minimal environment.
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
umask 077
LOGFILE=/var/log/health_check.log
PASS=0
FAIL=0

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo." >&2
    exit 2
fi
# Prevent concurrent cron/manual runs from attempting overlapping restarts.
exec 9>/run/server_health_check.lock
flock -n 9 || exit 0

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$1" | tee -a "$LOGFILE"
}

check_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        log "PASS: $service is running"
        ((PASS+=1))
    else
        log "FAIL: $service is not running; attempting restart"
        ((FAIL+=1))
        if systemctl restart "$service" && systemctl is-active --quiet "$service"; then
            log "RECOVERED: $service restarted successfully"
        else
            log "RECOVERY FAILED: $service requires administrator attention"
        fi
    fi
}

check_port() {
    local port="$1" name="$2"
    if [ -n "$(ss -H -ltn "sport = :$port")" ]; then
        log "PASS: TCP port $port ($name) has a listener"
        ((PASS+=1))
    else
        log "FAIL: TCP port $port ($name) has no listener"
        ((FAIL+=1))
    fi
}

check_disk() {
    local usage
    usage=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
    if [[ "$usage" =~ ^[0-9]+$ ]] && ((usage < 80)); then
        log "PASS: Root disk usage is $usage% (below 80%)"
        ((PASS+=1))
    else
        log "WARN: Root disk usage is ${usage:-unknown}% (threshold 80%)"
        ((FAIL+=1))
    fi
}

check_memory() {
    local available
    available=$(free -b | awk '/^Mem:/ {printf "%.0f", $7/$2*100}')
    if [[ "$available" =~ ^[0-9]+$ ]] && ((available > 10)); then
        log "PASS: Available memory is $available%"
        ((PASS+=1))
    else
        log "WARN: Available memory is ${available:-unknown}% (must exceed 10%)"
        ((FAIL+=1))
    fi
}

check_http() {
    local code
    code=$(curl --max-time 10 -s -o /dev/null -w '%{http_code}' http://127.0.0.1/) || code=000
    if [ "$code" = 200 ]; then
        log "PASS: HTTP response code is 200"
        ((PASS+=1))
    else
        log "FAIL: HTTP response code is $code (expected 200)"
        ((FAIL+=1))
    fi
}

log "Server Health Check Started"
check_service nginx
check_service firewalld
check_port 80 HTTP
check_port 22 SSH
check_disk
check_memory
check_http
log "Health Check Complete: PASS=$PASS | FAIL=$FAIL"
((FAIL == 0))
