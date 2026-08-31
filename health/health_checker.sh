#!/bin/bash
# health_checker.sh - Health check engine for IceWarp Health Agent
# This script evaluates the collected data against defined rules.

# ---------- Helper Functions ----------
days_ago() {
    local date_str="$1"
    if [[ -z "$date_str" ]]; then
        echo "0"
        return
    fi
    local date_epoch=$(date -d "$date_str" +%s 2>/dev/null)
    if [[ -z "$date_epoch" ]]; then
        echo "0"
        return
    fi
    local now_epoch=$(date +%s)
    local diff_sec=$((now_epoch - date_epoch))
    local diff_days=$((diff_sec / 86400))
    echo "$diff_days"
}

# ---------- Core Health Check Function ----------
# Receives JSON data and returns health results in a structured format
run_health_checks() {
    local json_data="$1"
    local results=()
    
    # --- 1. Backup Check ---
    local backup_enabled=$(echo "$json_data" | jq -r '.icewarp.backup.auto_enabled // 0')
    local backup_last=$(echo "$json_data" | jq -r '.icewarp.backup.last_time // ""')
    if [[ "$backup_enabled" == "1" ]] && [[ -n "$backup_last" ]]; then
        results+=("backup|pass|Automatic backup enabled, last run: $backup_last")
    else
        results+=("backup|fail|Automatic backup not enabled or never ran")
    fi
    
    # --- 2. CPU Load Check (Warn if > 50% of cores in 15-min) ---
    local load_15=$(echo "$json_data" | jq -r '.os.cpu.load15 // 0')
    local cpu_count=$(echo "$json_data" | jq -r '.os.cpu.count // 1')
    if [[ "$load_15" != "0" ]] && [[ "$cpu_count" != "0" ]]; then
        local cpu_percent=$(echo "scale=2; ($load_15 / $cpu_count) * 100" | bc 2>/dev/null || echo "0")
        local threshold=50
        if (( $(echo "$cpu_percent > $threshold" | bc -l 2>/dev/null || echo "0") )); then
            results+=("cpu|warn|1-min load (${load_15}) exceeds threshold approximation (${threshold}%)")
        else
            results+=("cpu|pass|1-min load (${load_15}) within threshold approximation (${threshold}%)")
        fi
    else
        results+=("cpu|skip|CPU data not available")
    fi
    
    # --- 3. Memory Usage (Warn if > 60%) ---
    local total_kb=$(echo "$json_data" | jq -r '.os.memory.total_kb // 0')
    local available_kb=$(echo "$json_data" | jq -r '.os.memory.available_kb // 0')
    if [[ "$total_kb" -gt 0 ]] && [[ "$available_kb" -ge 0 ]]; then
        local used_kb=$((total_kb - available_kb))
        local mem_percent=$(echo "scale=2; ($used_kb / $total_kb) * 100" | bc 2>/dev/null || echo "0")
        local threshold=60
        if (( $(echo "$mem_percent > $threshold" | bc -l 2>/dev/null || echo "0") )); then
            results+=("memory|warn|Memory usage is ${mem_percent}% (threshold: ${threshold}%)")
        else
            results+=("memory|pass|Memory usage is ${mem_percent}% (OK)")
        fi
    else
        results+=("memory|skip|Memory data not available")
    fi
    
    # --- 4. Disk Usage (Warn if > 80%) ---
    local disk_used_percent=$(echo "$json_data" | jq -r '.storage.root_fs.used_percent // "0%"' | sed 's/%//')
    if [[ -n "$disk_used_percent" ]] && [[ "$disk_used_percent" != "N/A" ]]; then
        local threshold=80
        if (( disk_used_percent >= threshold )); then
            results+=("disk|warn|Disk usage is ${disk_used_percent}% (threshold: ${threshold}%)")
        else
            results+=("disk|pass|Disk usage is ${disk_used_percent}% (OK)")
        fi
    else
        results+=("disk|skip|Disk usage data not available")
    fi
    
    # --- 5. OS Last Update (Warn if > 3 days) ---
    local last_update=$(echo "$json_data" | jq -r '.os.last_update_date // ""')
    if [[ -n "$last_update" ]] && [[ "$last_update" != "null" ]]; then
        local days=$(days_ago "$last_update")
        if (( days > 3 )); then
            results+=("os_update|warn|OS last update was $days days ago (threshold: 3 days)")
        else
            results+=("os_update|pass|OS last update was $days days ago (OK)")
        fi
    else
        results+=("os_update|skip|OS last update date not available")
    fi
    
    # --- 6. DIGEST-MD5 (Security) ---
    local digest_md5=$(echo "$json_data" | jq -r '.security.digest_md5.enabled // false')
    if [[ "$digest_md5" == "false" ]]; then
        results+=("digest_md5|pass|DIGEST-MD5 auth scheme is disabled")
    else
        results+=("digest_md5|warn|DIGEST-MD5 auth scheme is still enabled (weak, legacy)")
    fi
    
    # --- 7. Login Policy / Intrusion Prevention ---
    local login_policy=$(echo "$json_data" | jq -r '.security.login.policy_enabled // 0')
    local block_failed=$(echo "$json_data" | jq -r '.security.intrusion.block_failed_logins.enabled // 0')
    local block_value=$(echo "$json_data" | jq -r '.security.intrusion.block_failed_logins.value // 0')
    if [[ "$login_policy" == "1" ]]; then
        results+=("login_blocking|pass|Login Policy lockout active, threshold ($block_value) OK")
    elif [[ "$block_failed" == "1" ]]; then
        results+=("login_blocking|pass|Login Policy lockout is off, but Intrusion Prevention blocks the IP after $block_value failed logins")
    else
        results+=("login_blocking|fail|Neither Login Policy lockout nor Intrusion Prevention failed-login blocking is active")
    fi
    
    # --- 8. TLS Delivery ---
    local use_tls=$(echo "$json_data" | jq -r '.smtp.use_tls_ssl // 0')
    if [[ "$use_tls" == "1" ]]; then
        results+=("tls_delivery|pass|TLS/SSL for delivery is enabled")
    else
        results+=("tls_delivery|warn|TLS/SSL for delivery is not enabled")
    fi
    
    # --- 9. Password Policy ---
    local pass_active=$(echo "$json_data" | jq -r '.security.password_policy.active // 0')
    local pass_min_len=$(echo "$json_data" | jq -r '.security.password_policy.min_length // 0')
    if [[ "$pass_active" == "1" ]]; then
        if (( pass_min_len >= 10 )); then
            results+=("password_policy|pass|Password policy active, min length $pass_min_len meets recommendation")
        else
            results+=("password_policy|warn|Password policy active but min length ($pass_min_len) is below recommended 10")
        fi
    else
        results+=("password_policy|skip|Password policy is not active")
    fi
    
    # --- 10. Monitor (if applicable) ---
    local monitor_enabled=$(echo "$json_data" | jq -r '.monitor.enabled // 0')
    if [[ "$monitor_enabled" == "1" ]]; then
        local mem_alert=$(echo "$json_data" | jq -r '.monitor.memory.alert_below_kb // 0')
        local avail_mem=$(echo "$json_data" | jq -r '.os.memory.available_kb // 0')
        if [[ "$mem_alert" -gt 0 ]] && [[ "$avail_mem" -lt "$mem_alert" ]]; then
            results+=("memory_monitor|fail|Available memory (${avail_mem}KB) is below the server's configured alert threshold (${mem_alert}KB)")
        elif [[ "$mem_alert" -gt 0 ]]; then
            results+=("memory_monitor|pass|Available memory (${avail_mem}KB) is OK")
        else
            results+=("memory_monitor|skip|System Monitor memory threshold not configured on server")
        fi
    else
        results+=("memory_monitor|skip|System Monitor is disabled")
    fi
    
    # Output results as JSON
    echo "$results" | jq -R -s -c 'split("\n")[:-1] | map(split("|") | {id: .[0], status: .[1], message: .[2]})'
}

# ---------- Main (if executed directly) ----------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced by agent.sh"
    echo "Usage: source health/health_checker.sh"
    echo "Then call: run_health_checks \"\$json_data\""
fi
