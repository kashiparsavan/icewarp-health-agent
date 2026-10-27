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
    
    # --- 3. Memory Usage (Strict Override: >90% CRITICAL, >40% WARN) ---
    local total_kb=$(echo "$json_data" | jq -r '.os.memory.total_kb // 0')
    local available_kb=$(echo "$json_data" | jq -r '.os.memory.available_kb // 0')
    local ram_note="Total(KB)=${total_kb} / Available KB=${available_kb}"
    if [[ "$total_kb" -gt 0 ]] && [[ "$available_kb" -ge 0 ]]; then
        local used_kb=$((total_kb - available_kb))
        local mem_percent=$(echo "scale=2; ($used_kb / $total_kb) * 100" | bc 2>/dev/null || echo "0")
        if (( $(echo "$mem_percent > 90" | bc -l 2>/dev/null || echo "0") )); then
            results+=("memory|critical|${ram_note}")
        elif (( $(echo "$mem_percent > 40" | bc -l 2>/dev/null || echo "0") )); then
            results+=("memory|warn|${ram_note}")
        else
            results+=("memory|pass|${ram_note}")
        fi
    else
        results+=("memory|warn|${ram_note}")
    fi
    
    # --- 4. Disk Usage (Strict Override: >=95% CRITICAL, >=80% WARN) ---
    local total_gb=$(echo "$json_data" | jq -r '.storage.root_fs.total_gb // 0')
    local disk_used_percent=$(echo "$json_data" | jq -r '.storage.root_fs.used_percent // "0%"' | sed 's/%//')
    local disk_note="Total(GB)=${total_gb} / Used %=${disk_used_percent}"
    if [[ -n "$disk_used_percent" ]] && [[ "$disk_used_percent" != "N/A" ]]; then
        if (( disk_used_percent >= 95 )); then
            results+=("disk|critical|${disk_note}")
        elif (( disk_used_percent >= 80 )); then
            results+=("disk|warn|${disk_note}")
        else
            results+=("disk|pass|${disk_note}")
        fi
    else
        results+=("disk|warn|${disk_note}")
    fi
    
    # --- 5. OS Last Update (Warn if > 7 days, matches health.sh) ---
    local last_update=$(echo "$json_data" | jq -r '.os.last_update_date // ""')
    if [[ -n "$last_update" ]] && [[ "$last_update" != "null" ]]; then
        local days=$(days_ago "$last_update")
        if (( days > 30 )); then
            results+=("os_update|critical|OS is outdated (${days} days since last update)")
        elif (( days > 7 )); then
            results+=("os_update|warn|OS update is ${days} days old (consider updating within a week)")
        else
            results+=("os_update|pass|OS updated recently (${days} days ago)")
        fi
    else
        results+=("os_update|warn|OS last update date not available")
    fi
    
    # --- 6. DIGEST-MD5 (Security) Strict Override: true=CRITICAL (enabled=bad), false=PASS (disabled=good), missing=CRITICAL ---
    local digest_md5=$(echo "$json_data" | jq -r '.security.digest_md5.enabled // ""')
    if [[ "$digest_md5" == "true" ]]; then
        results+=("digest_md5|critical|DIGEST-MD5 auth scheme is ENABLED (weak, legacy)")
    elif [[ "$digest_md5" == "false" ]]; then
        results+=("digest_md5|pass|DIGEST-MD5 auth scheme is disabled")
    else
        results+=("digest_md5|critical|Auth scheme list not available - cannot verify DIGEST-MD5 status")
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
    
    # --- 7b. Intrusion Prevention Thresholds (Strict Override: hardcoded 50/360) ---
    local cpms=$(echo "$json_data" | jq -r '.security.intrusion.block_connections_per_minute.value // ""')
    if [[ -z "$cpms" ]] || [[ "$cpms" == "null" ]]; then
        results+=("intrusion.block_connections|critical|Block IP - Connections in 1 Minute setting not found")
    elif [[ "$cpms" == "50" ]]; then
        results+=("intrusion.block_connections|pass|Block IP - Connections in 1 Minute is 50 (expected 50)")
    else
        results+=("intrusion.block_connections|warn|Block IP - Connections in 1 Minute is $cpms (expected 50)")
    fi
    
    local block_dur=$(echo "$json_data" | jq -r '.security.intrusion.block_duration_minutes // ""')
    if [[ -z "$block_dur" ]] || [[ "$block_dur" == "null" ]]; then
        results+=("intrusion.block_duration|critical|Amount of Time IP is Blocked setting not found")
    elif [[ "$block_dur" == "360" ]]; then
        results+=("intrusion.block_duration|pass|Amount of Time IP is Blocked is 360 minutes (expected 360)")
    else
        results+=("intrusion.block_duration|warn|Amount of Time IP is Blocked is $block_dur minutes (expected 360)")
    fi

    # --- 7c. Admin Email (Strict Override: empty=CRITICAL, invalid=WARN) ---
    local admin_email=$(echo "$json_data" | jq -r '.monitor.alert_email // ""')
    if [[ -z "$admin_email" ]] || [[ "$admin_email" == "null" ]] || [[ "$admin_email" == "N/A" ]]; then
        results+=("admin_email|critical|Admin email is not set")
    elif [[ "$admin_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        results+=("admin_email|pass|Admin email is configured: $admin_email")
    else
        results+=("admin_email|warn|Admin email is set but invalid format: $admin_email")
    fi

    # --- 7d. Session Timeout (Strict Override: has value=PASS, missing=WARN) ---
    local session_timeout=$(echo "$json_data" | jq -r '.icewarp.session_timeout_minutes // ""')
    if [[ -n "$session_timeout" ]] && [[ "$session_timeout" != "null" ]] && [[ "$session_timeout" != "N/A" ]] && [[ "$session_timeout" != "0" ]]; then
        results+=("session_timeout|pass|Session timeout is configured: $session_timeout minutes")
    else
        results+=("session_timeout|warn|Session timeout is not set or is 0")
    fi

    # --- 7e. IMAP / POP3 Services (Strict Override: Running=PASS, Disabled=WARN) ---
    local imap_active=$(echo "$json_data" | jq -r '.service.imap.active // 0')
    local pop3_active=$(echo "$json_data" | jq -r '.service.pop3.active // 0')
    if [[ "$imap_active" == "1" ]] || [[ "$imap_active" == "true" ]]; then
        results+=("service.imap|pass|IMAP service is running")
    else
        results+=("service.imap|warn|IMAP service is disabled")
    fi
    if [[ "$pop3_active" == "1" ]] || [[ "$pop3_active" == "true" ]]; then
        results+=("service.pop3|pass|POP3 service is running")
    else
        results+=("service.pop3|warn|POP3 service is disabled")
    fi
    
    # --- 7h. Password Policy ---
    local pass_active=$(echo "$json_data" | jq -r '.security.password_policy.active // 0')
    local pass_min_len=$(echo "$json_data" | jq -r '.security.password_policy.min_length // 0')
    if [[ "$pass_active" == "1" ]]; then
        if (( pass_min_len >= 8 )); then
            results+=("password_policy|pass|Password policy active, min length $pass_min_len meets recommendation")
        else
            results+=("password_policy|warn|Password policy active but min length ($pass_min_len) below recommended 8")
        fi
    else
        results+=("password_policy|fail|Password policy is not active")
    fi

    # --- 8. TLS Delivery ---
    local use_tls=$(echo "$json_data" | jq -r '.smtp.use_tls_ssl // 0')
    if [[ "$use_tls" == "1" ]]; then
        results+=("tls_delivery|pass|TLS/SSL for delivery is enabled")
    else
        results+=("tls_delivery|fail|TLS/SSL for delivery is NOT enabled")
    fi
    
    # --- 7f. Database Type (Strict Override: SQLite=WARN, MySQL=PASS, no INFO) ---
    local db_type=$(echo "$json_data" | jq -r '.database.type // ""')
    if [[ "$db_type" == "sqlite" ]]; then
        results+=("database|warn|SQLite is in use; MySQL is recommended for production")
    elif [[ "$db_type" == "mysql" ]]; then
        results+=("database|pass|MySQL database platform is active")
    else
        results+=("database|warn|Database type could not be determined (unknown/empty)")
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
