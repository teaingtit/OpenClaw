# Local Inference (Ollama on ryzenpc)

OpenClaw can use **Ollama on ryzenpc** (Tailscale `100.82.51.31:11434`) as a local model backend. This reduces API cost to zero and keeps data on-premises.

## Routing strategy

| Task category     | Local model (Ollama)      | Cloud fallback (OpenRouter)          |
| ----------------- | ------------------------- | ------------------------------------ |
| General reasoning | `ollama/qwen2.5:7b`       | `openrouter/google/gemini-2.5-flash` |
| Coding            | `ollama/qwen2.5-coder:7b` | `openrouter/minimax/minimax-m2.5`    |
| Fast / simple     | `ollama/llama3.2:3b`      | `openrouter/z-ai/glm-4.7-flash`      |
| Embedding (RAG)   | `ollama/nomic-embed-text` | — (local only)                       |
| Vision / OCR      | `ollama/minicpm-v:8b`     | — (local only)                       |

Agent config in `openclaw.json` can set `model.primary` to an `ollama/...` model and `model.fallbacks` to OpenRouter for when ryzenpc is offline or overloaded.

## VRAM and concurrency (8GB RTX 4060)

- Only **one** 7–8B model fits in VRAM at a time (~4.5–5.5 GB).
- Model swap latency is ~2–5 s when switching models.
- **Note**: Audio services (Whisper, Parler-TTS) are installed but **disabled by default** to reserve VRAM for LLM inference. Enable them manually when needed.
- **OLLAMA_KEEP_ALIVE**: set on ryzenpc so idle models are unloaded (e.g. `5m`). Run when ryzenpc is reachable:
  ```bash
  ./scripts/configure-ollama-keepalive.sh 5m
  ```
- In **n8n** workflows that call Ollama: use **concurrency limit 1** for GPU tasks; add **retry with backoff** on 503 (model loading); batch similar tasks to reduce model swaps.

## n8n

- Workflow templates: [docs/workflows/n8n/](workflows/n8n/).
- Ollama base URL in nodes: `http://100.82.51.31:11434`.
- For gateway health (e.g. Daily Health Report): from host use `http://127.0.0.1:18789` or Tailscale; from Docker use `http://host.docker.internal:18789` if available.

## JIT wake

If ryzenpc is off, use the JIT wrapper so it is woken before calling Ollama:

```bash
./scripts/jit-wrapper.sh "curl -s http://localhost:11434/api/tags"
```
