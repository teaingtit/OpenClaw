#!/bin/bash
# pull-worker-models.sh — Pull all specialized AI models on ryzenpc via SSH
# Usage: ./scripts/pull-worker-models.sh [--group N] [--dry-run]
#   --group 1-5   Pull only a specific group (1=reasoning, 2=coding, 3=vision, 4=embedding, 5=all-small)
#   --dry-run     Show what would be pulled without actually pulling

set -euo pipefail

SSH_CONFIG="/home/teaingtit/.openclaw/workspace-father/ssh_config"
SSH_CMD="ssh -F $SSH_CONFIG ryzenpc"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

GROUP=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --group) GROUP="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# --- Model Groups ---
# Group 1: Logical Reasoning & General Text
GROUP1_MODELS=(
    "deepseek-r1:8b"           # Complex Reasoning, CoT
    "qwen2.5:7b"               # Agentic Workflow, Tool Calling
    "mistral:7b"               # General Text Processing (Ministral family)
    "llama3.2:3b"              # Fast Instruction Following
    "gemma2:2b"                # Translation, Text Formatting
)

# Group 2: Software Engineering
GROUP2_MODELS=(
    "qwen2.5-coder:7b"        # Autonomous Coding, Bug Fixing
    "starcoder2:3b"            # Lightweight Scripting, CI/CD
    "qwen2.5-coder:1.5b"      # Inline Code Autocomplete (ultra-fast)
)

# Group 3: Vision & Multimodal
GROUP3_MODELS=(
    "minicpm-v:8b"             # Edge Multimodal, Image Understanding
    "moondream:latest"         # Real-time OCR, Video Stream (~1.8B)
    "llava:7b"                 # Visual Question Answering
)

# Group 4: Embedding & RAG (can run on CPU, small footprint)
GROUP4_MODELS=(
    "nomic-embed-text"         # Text Embedding for Vector DB
    "bge-m3"                   # Multilingual Dense/Sparse Retrieval
)

# Group 5: Specialized (math, additional reasoning)
GROUP5_MODELS=(
    "qwen2-math:7b"            # Mathematical Reasoning
)

pull_models() {
    local group_name="$1"
    shift
    local models=("$@")

    echo ""
    echo "========================================"
    echo "  Pulling $group_name"
    echo "========================================"

    for model in "${models[@]}"; do
        echo ""
        echo "--- Pulling: $model ---"
        if $DRY_RUN; then
            echo "[DRY-RUN] Would pull: $model"
        else
            if $SSH_CMD "ollama pull '$model'" 2>&1; then
                echo "[OK] $model"
            else
                echo "[FAIL] $model (exit code: $?)"
            fi
        fi
    done
}

# Verify ryzenpc is reachable
echo "Checking ryzenpc connectivity..."
if ! $SSH_CMD "echo OK" >/dev/null 2>&1; then
    echo "ryzenpc is not reachable via SSH. Attempting WoL..."
    "$SCRIPT_DIR/wake-ai.sh"
    echo "Waiting 60s for boot..."
    sleep 60
    if ! $SSH_CMD "echo OK" >/dev/null 2>&1; then
        echo "ERROR: ryzenpc still unreachable after WoL. Aborting."
        exit 1
    fi
fi

echo "ryzenpc is online. Ollama version:"
$SSH_CMD "ollama --version"
echo ""
echo "Disk space:"
$SSH_CMD "df -h / | tail -1"
echo ""

case "${GROUP:-all}" in
    1) pull_models "Group 1: Reasoning & General" "${GROUP1_MODELS[@]}" ;;
    2) pull_models "Group 2: Software Engineering" "${GROUP2_MODELS[@]}" ;;
    3) pull_models "Group 3: Vision & Multimodal" "${GROUP3_MODELS[@]}" ;;
    4) pull_models "Group 4: Embedding & RAG" "${GROUP4_MODELS[@]}" ;;
    5) pull_models "Group 5: Specialized" "${GROUP5_MODELS[@]}" ;;
    all)
        pull_models "Group 1: Reasoning & General" "${GROUP1_MODELS[@]}"
        pull_models "Group 2: Software Engineering" "${GROUP2_MODELS[@]}"
        pull_models "Group 3: Vision & Multimodal" "${GROUP3_MODELS[@]}"
        pull_models "Group 4: Embedding & RAG" "${GROUP4_MODELS[@]}"
        pull_models "Group 5: Specialized" "${GROUP5_MODELS[@]}"
        ;;
    *) echo "Invalid group: $GROUP (use 1-5 or omit for all)"; exit 1 ;;
esac

echo ""
echo "========================================"
echo "  Pull complete! Installed models:"
echo "========================================"
$SSH_CMD "ollama list"
echo ""
echo "Disk usage after pull:"
$SSH_CMD "df -h / | tail -1"
