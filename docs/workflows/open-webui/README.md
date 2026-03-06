# Open WebUI (minipc → Ollama on ryzenpc)

Open WebUI ให้ใช้ Ollama ผ่านเว็บได้ โดยรัน UI บน **minipc** และให้เชื่อมต่อกับ **Ollama บน ryzenpc** ผ่าน Tailscale

## ความต้องการ

- **minipc** (100.96.9.50): รัน Docker และ Tailscale
- **ryzenpc** (100.82.51.31): รัน Ollama ที่พอร์ต 11434 และอยู่ในเครือข่าย Tailscale เดียวกับ minipc

## วิธีรันบน minipc

จาก repo (หรือจาก minipc ที่โคลน openclaw ไว้):

```bash
# รันแบบ detached
docker compose -f docs/workflows/open-webui/docker-compose.example.yml up -d

# ดู logs
docker compose -f docs/workflows/open-webui/docker-compose.example.yml logs -f open-webui
```

หรือรันด้วย `docker run` โดยตรง (ถ้าไม่ได้ใช้ compose):

```bash
docker run -d \
  -p 3000:8080 \
  -e OLLAMA_BASE_URL=http://100.82.51.31:11434 \
  -e OLLAMA_API_BASE_URL=http://100.82.51.31:11434 \
  -e WEBUI_AUTH=true \
  -e WEBUI_URL=http://100.96.9.50:3000 \
  -v open_webui_data:/app/backend/data \
  --name open-webui \
  --restart unless-stopped \
  ghcr.io/open-webui/open-webui:main
```

## การเข้าใช้

- จากเครื่องในเครือข่าย Tailscale เดียวกัน: เปิดเบราว์เซอร์ที่ **http://100.96.9.50:3000**
- ถ้ารันบน minipc เอง: **http://localhost:3000**

ครั้งแรกจะต้อง **สร้างบัญชี admin** ใน UI (เปิดหน้าแล้วสมัคร/ล็อกอิน)

## การเชื่อมต่อ Ollama

- Open WebUI ใช้ตัวแปร `OLLAMA_BASE_URL` / `OLLAMA_API_BASE_URL` ชี้ไปที่ **http://100.82.51.31:11434** (ryzenpc)
- โมเดลที่เห็นใน UI จะเป็นโมเดลที่ติดตั้งบน Ollama ที่ ryzenpc (ดูรายการได้จาก `ollama list` บน ryzenpc)

## ถ้าเชื่อมต่อ Ollama ไม่ได้

ถ้า container รันแล้วแต่ใน UI แสดงว่าเชื่อมต่อ Ollama ไม่ได้:

1. ตรวจว่า minipc รัน Tailscale และ `ping 100.82.51.31` ได้
2. ตรวจว่า Ollama บน ryzenpc เปิดอยู่: `curl -s http://100.82.51.31:11434/api/tags` (รันจาก minipc)
3. ลองใช้โหมด host network (แชร์ network กับ minipc):
   - ใน compose เพิ่ม `network_mode: host` แล้วลบ `ports`
   - เปิด Open WebUI ที่ **http://localhost:8080** (หรือ IP ของ minipc:8080)

## อัปเดต image

```bash
docker pull ghcr.io/open-webui/open-webui:main
docker compose -f docs/workflows/open-webui/docker-compose.example.yml up -d
```
