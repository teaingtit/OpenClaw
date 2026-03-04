#!/usr/bin/env bash
# Rebuild the openclaw:local Docker image and recreate the gateway container.
# Run from the repo root: bash scripts/docker-rebuild.sh
#
# When systemd is primary (openclaw-gateway.service), do NOT run this script —
# it starts the Docker gateway (port 18789) and will conflict. Use systemctl --user for gateway.
#
# Options:
#   --browser   Include Chromium/Playwright for browser automation (~300MB extra)
#   --gh        Include GitHub CLI (gh) for code review / PR management
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml -f $REPO_ROOT/docker-compose.override.yml"

BUILD_ARGS=""
for arg in "$@"; do
  case "$arg" in
    --browser) BUILD_ARGS="$BUILD_ARGS --build-arg OPENCLAW_INSTALL_BROWSER=1" ;;
    --gh)      BUILD_ARGS="$BUILD_ARGS --build-arg OPENCLAW_INSTALL_GH=1" ;;
  esac
done

echo "→ Building openclaw:local image${BUILD_ARGS:+ ($BUILD_ARGS)}..."
# shellcheck disable=SC2086
docker build $BUILD_ARGS -t openclaw:local -f "$REPO_ROOT/Dockerfile" "$REPO_ROOT"

echo "→ Recreating gateway container..."
$COMPOSE --profile docker-gateway up -d --no-deps openclaw-gateway

echo "→ Waiting for healthcheck..."
sleep 8
$COMPOSE ps openclaw-gateway

echo "→ Verifying config sanity..."
# Check trustedProxies includes Docker bridge IP
BRIDGE_IP=$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null || echo "")
CONFIG="$HOME/.openclaw/openclaw.json"
if [ -f "$CONFIG" ]; then
  PROXIES=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(' '.join(c.get('gateway',{}).get('trustedProxies',[])))" 2>/dev/null || echo "")
  if [ -n "$BRIDGE_IP" ] && ! echo "$PROXIES" | grep -q "$BRIDGE_IP"; then
    echo "  ⚠️  WARN: Docker bridge IP $BRIDGE_IP is NOT in gateway.trustedProxies"
    echo "     Add it to openclaw.json → gateway.trustedProxies to suppress proxy warnings."
  else
    echo "  ✓ trustedProxies OK"
  fi

  # Check required inter-agent communication flags
  AGENT_TO_AGENT=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('tools',{}).get('agentToAgent',{}).get('enabled','false'))" 2>/dev/null || echo "false")
  SESSION_VIS=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('tools',{}).get('sessions',{}).get('visibility',''))" 2>/dev/null || echo "")
  MISSING_FLAGS=""
  [ "$AGENT_TO_AGENT" != "True" ] && [ "$AGENT_TO_AGENT" != "true" ] && MISSING_FLAGS="$MISSING_FLAGS tools.agentToAgent.enabled=true"
  [ "$SESSION_VIS" != "all" ] && MISSING_FLAGS="$MISSING_FLAGS tools.sessions.visibility=all"
  if [ -n "$MISSING_FLAGS" ]; then
    echo "  ✗ ERROR: Required inter-agent config flags missing:$MISSING_FLAGS"
    echo "     Without these, ALL agent-to-agent delegation silently fails."
    echo "     Add to openclaw.json root level:"
    echo '     "tools": { "sessions": { "visibility": "all" }, "agentToAgent": { "enabled": true } }'
    echo "     Then re-run this script."
    exit 1
  else
    echo "  ✓ inter-agent flags OK (agentToAgent.enabled=true, sessions.visibility=all)"
  fi

  # If browser is enabled, verify executablePath is set
  BROWSER_ENABLED=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('browser',{}).get('enabled','false'))" 2>/dev/null || echo "false")
  EXEC_PATH=$(python3 -c "import json; c=json.load(open('$CONFIG')); print(c.get('browser',{}).get('executablePath',''))" 2>/dev/null || echo "")
  if [ "$BROWSER_ENABLED" = "True" ] || [ "$BROWSER_ENABLED" = "true" ]; then
    if [ -z "$EXEC_PATH" ]; then
      echo "  ⚠️  WARN: browser.enabled=true but executablePath is not set."
      echo "     Run: docker exec openclaw-openclaw-gateway-1 find /home/node/.cache/ms-playwright -name chrome -type f"
      echo "     Then set browser.executablePath in openclaw.json"
    else
      # Verify the path actually exists in the container
      if $COMPOSE exec -T openclaw-gateway test -f "$EXEC_PATH" 2>/dev/null; then
        echo "  ✓ browser.executablePath OK ($EXEC_PATH)"
      else
        echo "  ⚠️  WARN: browser.executablePath set but file not found in container: $EXEC_PATH"
        echo "     Rebuild with: bash scripts/docker-rebuild.sh --browser"
      fi
    fi
  fi
fi

echo "→ Checking gateway logs for early warnings..."
sleep 3
$COMPOSE logs --tail=20 openclaw-gateway 2>/dev/null | grep -E "WARN|ERROR|error" | grep -v "^$" || echo "  ✓ No WARN/ERROR in initial logs"

echo "✓ Done."

# Post-build: check for gh CLI if --gh was used
if echo "$BUILD_ARGS" | grep -q "OPENCLAW_INSTALL_GH"; then
  GH_VERSION=$($COMPOSE exec -T openclaw-gateway gh --version 2>/dev/null | head -1 || echo "")
  if [ -n "$GH_VERSION" ]; then
    echo "  ✓ GitHub CLI installed: $GH_VERSION"
    echo "  → Run 'docker exec -it openclaw-openclaw-gateway-1 gh auth login' to authenticate"
  else
    echo "  ⚠️  WARN: --gh was used but gh CLI not found in container"
  fi
fi
