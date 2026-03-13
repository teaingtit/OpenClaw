#!/usr/bin/env bash
# network-diagnostics.sh — check internet, DNS, Tailscale, gateway HTTP, listening ports
# Exit code: 0 = ok, 1 = DNS/Tailscale issue, 2 = no internet or no route
#
# Usage: network-diagnostics.sh [--format json|verbose]

set -euo pipefail

FORMAT="json"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"

for arg in "$@"; do
  case "$arg" in
    --format=*) FORMAT="${arg#--format=}" ;;
    --format) shift; [ -n "${1:-}" ] && FORMAT="$1" ;;
    --verbose) FORMAT="verbose" ;;
  esac
done

ts=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

# Internet ping
ping_1111="fail"
ping_8888="fail"
if command -v ping >/dev/null 2>&1; then
  ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 && ping_1111="ok"
  ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 && ping_8888="ok"
fi

internet="ok"
[ "$ping_1111" = "fail" ] && [ "$ping_8888" = "fail" ] && internet="down"

# DNS resolve
dns_resolve="fail"
if command -v host >/dev/null 2>&1; then
  host -W 3 google.com >/dev/null 2>&1 && dns_resolve="ok"
elif command -v dig >/dev/null 2>&1; then
  dig +short +time=3 google.com >/dev/null 2>&1 && dns_resolve="ok"
elif command -v nslookup >/dev/null 2>&1; then
  nslookup -timeout=3 google.com >/dev/null 2>&1 && dns_resolve="ok"
fi

# Default route
default_route="none"
if command -v ip >/dev/null 2>&1; then
  default_route=$(ip route show default 2>/dev/null | head -1 | awk '{print $3}' || echo "none")
fi
[ -z "$default_route" ] && default_route="none"

# Tailscale status
tailscale_status="not_installed"
tailscale_ip=""
if command -v tailscale >/dev/null 2>&1; then
  if command -v jq >/dev/null 2>&1; then
    tailscale_status=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "error"' 2>/dev/null || echo "error")
    tailscale_ip=$(tailscale status --json 2>/dev/null | jq -r '.TailscaleIPs[0] // ""' 2>/dev/null || echo "")
  else
    ts_state=$(tailscale status 2>/dev/null | head -1 || echo "")
    [ -n "$ts_state" ] && tailscale_status="detected" || tailscale_status="error"
  fi
fi

# Gateway HTTP health
gateway_health="down"
if command -v curl >/dev/null 2>&1; then
  http_code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 "http://localhost:$GATEWAY_PORT/health" 2>/dev/null || echo "000")
  [ "$http_code" = "200" ] && gateway_health="ok"
fi

# Listening ports (top 20)
listening_ports=""
if command -v ss >/dev/null 2>&1; then
  listening_ports=$(ss -ltnp 2>/dev/null | tail -n +2 | head -20 | awk '{gsub(/"/, "", $6); printf "{\"addr\":\"%s\",\"proc\":\"%s\"},", $4, $6}' | sed 's/,$//')
fi

# --- Status ---
status="ok"
exit_code=0

if [ "$dns_resolve" = "fail" ] || [ "$tailscale_status" = "Stopped" ] || [ "$tailscale_status" = "error" ]; then
  status="warning"
  exit_code=1
fi

if [ "$internet" = "down" ] || [ "$default_route" = "none" ]; then
  status="critical"
  exit_code=2
fi

# --- Output ---
if [ "$FORMAT" = "verbose" ]; then
  echo "Network Diagnostics — $ts"
  echo "  Internet:           $internet (1.1.1.1: $ping_1111, 8.8.8.8: $ping_8888)"
  echo "  DNS resolve:        $dns_resolve"
  echo "  Default route:      $default_route"
  echo "  Tailscale:          $tailscale_status${tailscale_ip:+ ($tailscale_ip)}"
  echo "  Gateway HTTP:       $gateway_health (port $GATEWAY_PORT)"
  echo "  Status:             $status"
  echo ""
  echo "Listening ports:"
  ss -ltnp 2>/dev/null | head -21
else
  printf '{"ts":"%s","internet":"%s","ping_1111":"%s","ping_8888":"%s","dns_resolve":"%s","default_route":"%s","tailscale_status":"%s","tailscale_ip":"%s","gateway_health":"%s","listening_ports":[%s],"status":"%s"}\n' \
    "$ts" "$internet" "$ping_1111" "$ping_8888" "$dns_resolve" "$default_route" "$tailscale_status" "$tailscale_ip" "$gateway_health" "$listening_ports" "$status"
fi

exit "$exit_code"
