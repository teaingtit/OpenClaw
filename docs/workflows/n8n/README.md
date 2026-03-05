# n8n Workflow Templates (OpenClaw + Ollama on ryzenpc)

Import these workflows into n8n at **http://100.96.9.50:5678** (sain-n8n).  
Ollama endpoint: **http://100.82.51.31:11434** (ryzenpc via Tailscale).

## Workflows

| File                                | Description                                                                                                                 |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `ollama-task-router.json`           | Webhook → classify task (llama3.2:3b) → route to coding/reasoning/vision/embedding/general/math/translation model → respond |
| `document-processing-pipeline.json` | Watch folder → read file → extract text → chunk → embed (nomic-embed-text) → notify Telegram                                |
| `daily-health-report.json`          | Cron 08:00 Bangkok → OpenClaw healthz + Ollama /api/tags → format report → Telegram                                         |

### Ollama Task Router — task types and models (ryzenpc 8GB VRAM)

| Type        | Model            | Use case                     |
| ----------- | ---------------- | ---------------------------- |
| coding      | qwen2.5-coder:7b | Code generation, scripting   |
| reasoning   | deepseek-r1:8b   | Chain-of-thought, analysis   |
| vision      | minicpm-v:8b     | Image understanding, OCR     |
| embedding   | nomic-embed-text | Text → vector (RAG/search)   |
| general     | qwen2.5:7b       | Chat, summarization, Q&A     |
| math        | qwen2-math:7b    | Math reasoning, equations    |
| translation | gemma2:2b        | Translation, text formatting |

Classifier: `llama3.2:3b`. Ensure all models are pulled on ryzenpc (`scripts/pull-worker-models.sh`).

## SAIN Product Evaluator (use local model)

To switch the existing **SAIN - Product Ingestion** (or evaluator) workflow from OpenRouter to local Ollama:

1. Open the workflow in n8n.
2. Find the node that calls OpenRouter / Gemini (e.g. "Evaluate product" or HTTP Request to OpenRouter).
3. Replace it (or add an HTTP Request node) with:
   - **Method:** POST
   - **URL:** `http://100.82.51.31:11434/api/generate`
   - **Body (JSON):**
     ```json
     {
       "model": "qwen2.5:7b",
       "prompt": "<your product + scoring instructions>",
       "stream": false
     }
     ```
4. Map the response: Ollama returns `{ "response": "..." }` — use `$json.response` in the next node.
5. Save and activate.

This avoids 429 Too Many Requests from OpenRouter and keeps evaluation local on ryzenpc.

## Standalone n8n Setup

For a fresh standalone instance (not on minipc where `sain-n8n` already runs), use the example compose:

```bash
docker compose -f docs/workflows/n8n/docker-compose.example.yml up -d
```

**Warning:** Do NOT run this on minipc — `sain-n8n` already occupies port 5678.

## Import

1. In n8n: **Workflows** → **Import from File** (or paste JSON).
2. Set credentials where needed: Telegram (for Notify/Send nodes), and `TG_NOTIFICATION_CHAT_ID` in the environment or in the node.
3. For **Daily Health Report**: ensure the container can reach `http://host.docker.internal:18789` (OpenClaw gateway on host). If using sain-n8n on the same host, use `http://127.0.0.1:18789` or the host’s Tailscale IP.

## Concurrency and retry (Minimal Optimization)

- **Concurrency:** Template JSONs set `settings.maxConcurrency: 1` where applicable. After import, in n8n open **Workflow Settings** (gear) → **Concurrency** → enable **Limit** → **Max: 1** for: Ollama Task Router, Document Processing Pipeline, and any workflow that calls Ollama (e.g. SAIN Product Ingestion).
- **Retry:** All HTTP Request nodes that call `http://100.82.51.31:11434` include **Retry on Fail** (3 tries, 5s between) to handle 503 while a model is loading.
- **Force Unload (async only):** Document Processing Pipeline includes a **Force Unload** node at the end (POST `keep_alive: 0` for `nomic-embed-text`). For the **SAIN Product Ingestion** workflow (existing in your n8n), add a final HTTP Request node: POST `http://100.82.51.31:11434/api/generate` with body `{"model": "qwen2.5:7b", "prompt": ".", "keep_alive": 0}` to free VRAM after the batch.
