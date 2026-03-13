#!/usr/bin/env bash
# security-audit.sh — report-only security audit: SSH, users, updates, firewall, ports, creds
# Exit code: 0 = clean, 1 = pending updates or >50 failed SSH, 2 = credentials exposed or >200 failed SSH
#
# Usage: security-audit.sh [--format json|verbose] [--hours N]

set -euo pipefail

FORMAT="json"
HOURS=24

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
    --hours=*) HOURS="${arg#--hours=}" ;;
    --hours) shift; [ -n "${1:-}" ] && HOURS="$1" ;;
  esac
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# Failed SSH attempts (last N hours)
failed_ssh=0
invalid_user_ssh=0
if command -v journalctl >/dev/null 2>&1; then
  failed_ssh=$(journalctl -u sshd -u ssh --since "${HOURS} hours ago" --no-pager 2>/dev/null | { grep -ci "failed password" || true; })
  invalid_user_ssh=$(journalctl -u sshd -u ssh --since "${HOURS} hours ago" --no-pager 2>/dev/null | { grep -ci "invalid user" || true; })
elif [ -f /var/log/auth.log ]; then
  failed_ssh=$(grep -ci "failed password" /var/log/auth.log 2>/dev/null | tail -1 || echo 0)
  invalid_user_ssh=$(grep -ci "invalid user" /var/log/auth.log 2>/dev/null | tail -1 || echo 0)
fi

# Logged-in users
logged_in_users=$(who 2>/dev/null | wc -l)
logged_in_list=$(who 2>/dev/null | awk '{printf "%s(%s) ", $1, $5}' | sed 's/ $//')

# Pending security updates
security_updates=0
total_upgradable=0
if command -v apt >/dev/null 2>&1; then
  total_upgradable=$(apt list --upgradable 2>/dev/null | { grep -c "upgradable" || true; })
  security_updates=$(apt list --upgradable 2>/dev/null | { grep -ci "security" || true; })
fi

# Firewall status
firewall_status="not_found"
if command -v ufw >/dev/null 2>&1; then
  ufw_out=$(sudo ufw status 2>/dev/null || ufw status 2>/dev/null || echo "inactive")
  if echo "$ufw_out" | grep -qi "active"; then
    firewall_status="active"
  else
    firewall_status="inactive"
  fi
elif command -v iptables >/dev/null 2>&1; then
  rule_count=$(sudo iptables -L -n 2>/dev/null | wc -l || iptables -L -n 2>/dev/null | wc -l || echo 0)
  [ "$rule_count" -gt 8 ] && firewall_status="iptables_active" || firewall_status="iptables_minimal"
fi

# Exposed 0.0.0.0 ports
exposed_ports=""
exposed_count=0
if command -v ss >/dev/null 2>&1; then
  exposed_ports=$(ss -ltnp 2>/dev/null | grep '0.0.0.0:\|:::' | awk '{printf "%s ", $4}' | sed 's/ $//')
  exposed_count=$(ss -ltnp 2>/dev/null | grep -c '0.0.0.0:\|:::' || echo 0)
fi

# Credential file permissions check
cred_issues=""
cred_issue_count=0
for cred_dir in "$HOME/.openclaw/credentials" "$HOME/.ssh" "$HOME/.openclaw"; do
  if [ -d "$cred_dir" ]; then
    # Check for world-readable files
    bad_perms=$(find "$cred_dir" -maxdepth 2 -type f \( -name "*.key" -o -name "*.pem" -o -name "*credential*" -o -name "*secret*" -o -name "*token*" -o -name "id_*" \) -perm /o=r 2>/dev/null || true)
    if [ -n "$bad_perms" ]; then
      cred_issue_count=$((cred_issue_count + $(echo "$bad_perms" | wc -l)))
      cred_issues="${cred_issues}${bad_perms}\n"
    fi
  fi
done

# --- Status ---
status="clean"
exit_code=0

if [ "$total_upgradable" -gt 0 ] || [ "$failed_ssh" -gt 50 ]; then
  status="warning"
  exit_code=1
fi

if [ "$cred_issue_count" -gt 0 ] || [ "$failed_ssh" -gt 200 ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
if [ "$FORMAT" = "verbose" ]; then
  echo "Security Audit — $ts (last ${HOURS}h)"
  echo "  Failed SSH:         $failed_ssh"
  echo "  Invalid user SSH:   $invalid_user_ssh"
  echo "  Logged-in users:    $logged_in_users ${logged_in_list:+($logged_in_list)}"
  echo "  Pending updates:    $total_upgradable (security: $security_updates)"
  echo "  Firewall:           $firewall_status"
  echo "  Exposed ports:      $exposed_count ${exposed_ports:+($exposed_ports)}"
  echo "  Credential issues:  $cred_issue_count"
  [ "$cred_issue_count" -gt 0 ] && printf "  Bad perms:\n%b" "$cred_issues"
  echo "  Status:             $status"
else
  printf '{"ts":"%s","hours":%s,"failed_ssh":%s,"invalid_user_ssh":%s,"logged_in_users":%s,"total_upgradable":%s,"security_updates":%s,"firewall":"%s","exposed_ports":%s,"credential_issues":%s,"status":"%s"}\n' \
    "$ts" "$HOURS" "$failed_ssh" "$invalid_user_ssh" "$logged_in_users" "$total_upgradable" "$security_updates" "$firewall_status" "$exposed_count" "$cred_issue_count" "$status"
fi

exit "$exit_code"
