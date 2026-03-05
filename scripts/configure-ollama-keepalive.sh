#!/bin/bash
# configure-ollama-keepalive.sh — Set OLLAMA_KEEP_ALIVE on ryzenpc to free VRAM after idle
# Run from minipc when ryzenpc is reachable. Usage: ./scripts/configure-ollama-keepalive.sh [5m]
# Default: 5m (unload model from VRAM after 5 minutes idle)

KEEP_ALIVE="${1:-5m}"
SSH_CONFIG="${OPENCLAW_FATHER_SSH_CONFIG:-/home/teaingtit/.openclaw/workspace-father/ssh_config}"
SSH_CMD="ssh -F $SSH_CONFIG ryzenpc"

set -euo pipefail

echo "Setting OLLAMA_KEEP_ALIVE=$KEEP_ALIVE on ryzenpc..."

$SSH_CMD "sudo mkdir -p /etc/systemd/system/ollama.service.d && sudo tee /etc/systemd/system/ollama.service.d/env.conf > /dev/null << 'ENVEOF'
[Service]
Environment=OLLAMA_MODELS=/home/teaingtit/ai-models
Environment=OLLAMA_HOST=0.0.0.0
Environment=OLLAMA_KEEP_ALIVE=$KEEP_ALIVE
ENVEOF
sudo systemctl daemon-reload && sudo systemctl restart ollama && sleep 2 && systemctl --no-pager show ollama | grep -i keep_alive || echo 'Ollama restarted (check env in journalctl -u ollama)'"

echo "Done. Ollama will unload models from VRAM after ${KEEP_ALIVE} idle."
