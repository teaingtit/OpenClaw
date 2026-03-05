import json
import os

with open("/home/teaingtit/.openclaw/openclaw.json", "r") as f:
    config = json.load(f)

print("--- Agent Audit ---")
for agent in config["agents"]["list"]:
    id = agent["id"]
    tools = agent.get("tools", {}).get("allow", [])
    model = agent.get("model", "")
    if isinstance(model, dict):
        model = model.get("primary", "")
    print(f"[{id}]")
    if not tools:
        print(f"  ERROR: No tools allowed!")
    elif tools == ["defaults"]:
         print(f"  WARNING: Using 'defaults' tools. Need explicit allowed list.")
    else:
        print(f"  Tools: {tools}")
