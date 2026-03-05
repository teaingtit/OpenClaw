import json
import os
import shutil

CONFIG_FILE = os.path.expanduser("~/.openclaw/openclaw.json")
BACKUP_FILE = os.path.expanduser("~/.openclaw/openclaw.json.bak.audit")

# Backup
shutil.copy2(CONFIG_FILE, BACKUP_FILE)
print(f"Backed up to {BACKUP_FILE}")

with open(CONFIG_FILE, "r") as f:
    config = json.load(f)

# 1. Fix broken tools
fixes = {
    "architect": ["read", "write", "exec", "sessions_send", "sessions_list", "session_status"],
    "coder": ["read", "write", "exec", "sessions_send", "session_status"],
    "qa-reviewer": ["read", "write", "sessions_send", "session_status"],
    "mother-relay": ["sessions_send", "sessions_list", "session_status"],
    "red-team": ["read", "write", "sessions_send", "session_status", "memory_search", "memory_get"]
}

for agent in config.get("agents", {}).get("list", []):
    agent_id = agent.get("id")
    if agent_id in fixes:
        if "tools" not in agent:
            agent["tools"] = {}
        agent["tools"]["allow"] = fixes[agent_id]
        print(f"Fixed tools for {agent_id}")

# 2. Add missing agents
existing_ids = {a.get("id") for a in config.get("agents", {}).get("list", [])}

missing_agents = [
    {
        "id": "deploy",
        "workspace": "/home/teaingtit/.openclaw/workspace-deploy",
        "model": {"primary": "openrouter/google/gemini-2.5-flash", "fallbacks": []},
        "identity": {"name": "Deploy Coordinator", "emoji": "🚀"},
        "tools": {"allow": ["read", "write", "exec", "sessions_send", "sessions_list", "sessions_spawn", "session_status"]}
    },
    {
        "id": "monitor",
        "workspace": "/home/teaingtit/.openclaw/workspace-monitor",
        "model": {"primary": "openrouter/google/gemini-2.5-flash", "fallbacks": []},
        "identity": {"name": "System Monitor", "emoji": "👁️"},
        "heartbeat": {"every": "15m"},
        "tools": {"allow": ["read", "exec", "sessions_send", "session_status"]}
    },
    {
        "id": "notifier",
        "workspace": "/home/teaingtit/.openclaw/workspace-notifier",
        "model": {"primary": "openrouter/google/gemini-2.5-flash", "fallbacks": []},
        "identity": {"name": "Notifier", "emoji": "📣"},
        "tools": {"allow": ["exec", "sessions_send", "session_status"]}
    },
    {
        "id": "intel",
        "workspace": "/home/teaingtit/.openclaw/workspace-intel",
        "model": {"primary": "openrouter/google/gemini-2.5-flash", "fallbacks": []},
        "identity": {"name": "Intel Unit", "emoji": "🕵️"},
        "heartbeat": {"every": "24h"},
        "tools": {"allow": ["read", "write", "browser", "sessions_send", "sessions_spawn", "sessions_list", "session_status", "memory_set", "memory_get"]}
    }
]

for ma in missing_agents:
    if ma["id"] not in existing_ids:
        config["agents"]["list"].append(ma)
        print(f"Added missing agent: {ma['id']}")
    else:
        print(f"Agent {ma['id']} already exists, skipping addition.")

# Write back
with open(CONFIG_FILE, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print("Successfully updated openclaw.json")
