# Audit: Ollama Task Router workflow

**File:** `ollama-task-router.json`  
**Audit date:** 2026-03-05

## n8n 2.10.x compatibility fixes applied

- **Switch node:** Use **Expression** mode instead of Rules (avoids “Could not find property option” in telemetry). Expression maps classification to output index 0–7; output 7 = fallback.
- **Webhook:** Removed empty `options: {}`.
- **HTTP Request nodes:** Removed `options` (timeout, retry) from JSON so API accepts; add retry/timeout in n8n UI after import if needed.
- **Import:** Use REST API `POST /api/v1/workflows` with body `{ name, nodes, connections, settings: { executionOrder: "v1" } }`. Activate with `POST /api/v1/workflows/{id}/activate`.

## Summary

| Check                                                               | Status                           |
| ------------------------------------------------------------------- | -------------------------------- |
| Valid JSON                                                          | OK                               |
| Node names unique                                                   | OK (11 nodes)                    |
| Connections reference existing nodes                                | OK                               |
| Webhook → Classify → Switch → 7 model branches + fallback → Respond | OK                               |
| Settings (executionOrder, maxConcurrency)                           | OK                               |
| Ollama URLs (ryzenpc)                                               | OK (`http://100.82.51.31:11434`) |

## Nodes (11)

1. **Webhook** — POST `/ollama-task`, `responseMode: responseNode`, webhookId `ollama-task-router`
2. **Classify Task** — HTTP POST to Ollama `/api/generate` (llama3.2:3b), prompt classifies into one of: coding, reasoning, vision, embedding, general, math, translation
3. **Switch by Type** — 7 rules + fallback "extra" by `$json.response` contains type
4. **Ollama Coding** — qwen2.5-coder:7b
5. **Ollama Reasoning** — deepseek-r1:8b
6. **Ollama Vision** — minicpm-v:8b
7. **Ollama Embedding** — nomic-embed-text, `/api/embed`, body `input`
8. **Ollama General** — qwen2.5:7b
9. **Ollama Math** — qwen2-math:7b
10. **Ollama Translation** — gemma2:2b
11. **Respond to Webhook** — JSON with `task_type` and `result` (uses `$json.response ?? $json` for embed branch)

## Connections

- Webhook → Classify Task → Switch by Type
- Switch outputs 0–7 → respective Ollama node or Respond (fallback)
- Each Ollama node → Respond to Webhook

All node names in `connections` match `nodes[].name`.

## Notes

- **Embedding branch:** Ollama `/api/embed` returns `{ embeddings: [[...]] }`; Respond uses `$json.response ?? $json` so fallback is full payload.
- **Switch operator:** Conditions use `operator: { "type": "string", "operation": "contains" }`. If n8n 2.10+ reports "Could not find property option", re-save the Switch node in the UI or adjust operator format per [n8n Switch node docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.switch/).
- **Webhook test:** `POST http://<n8n-host>:5678/webhook/ollama-task` with body `{"task": "...", "prompt": "..."}`. Requires ryzenpc Ollama reachable at `http://100.82.51.31:11434`.
