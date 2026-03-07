# 🖥️ ฮาร์ดแวร์และสถาปัตยกรรมระบบ (Hardware Details)

> **Purpose:** Single source of truth for this deployment's hardware, nodes, network, and SSH. For summary table and agent context, see **ANTIGRAVITY.md §3**. Scripts (pull models, Ollama keep-alive, etc.): **SCRIPTS_REGISTRY.md**.  
> **When to update:** When you add/change machines, IPs, SSH config, roles, or network — keep this file and ANTIGRAVITY.md §3 in sync.

## Quick reference (node_id ↔ alias ↔ Tailscale)

| node_id (ANTIGRAVITY §3) | SSH / alias  | Tailscale IP  | Role summary     |
| ------------------------ | ------------ | ------------- | ---------------- |
| `master_gateway`         | `ssh minipc` | `100.96.9.50` | Gateway, control |

| `client` | — | `100.71.184.70`| User/client machine |

---

## 1. Master Node / Gateway Server (Mini PC)

- **รุ่น**: Machenike Mini N TL24
- **CPU**: Intel(R) N150 (4 Cores, 4 Threads)
- **RAM**: 16GB LPDDR5
- **Storage**: 512GB SSD (HOGE H671)
- **Network / Ports**: Dual LAN, WiFi 5, Bluetooth 5.0, USB 3.2 x3, HDMI 2.0 x3, Audio x1
- **OS**: Ubuntu Server 26.04 LTS (dev branch - รัน 24/7)
- **หน้าที่หลัก**: เป็น System Control Center ควบคุมและกระจายงานในเครือข่าย
- **Tailscale IP**: `100.96.9.50`
- **SSH**: `ssh minipc` (ใช้ Key: `teaingtit`)
- **OpenClaw**: Gateway (port `18789`); systemd user service or Docker — run exactly one. See ANTIGRAVITY.md §7.0.

## 3. Client Node (ASUS ExpertBook)

- **รุ่น**: ASUS EXPERTBOOK P3605CVA
- **CPU**: 13th Gen Intel(R) Core(TM) i5-13420H (8 Cores, 12 Threads)
- **RAM**: 16GB (Samsung, Bus 5600)
- **Storage**: 1TB NVMe SSD (SAMSUNG MZVMA1T0HCLD-00BTW)
- **GPU**: Intel UHD Graphics (2GB VRAM)
- **OS**: Windows
- **Tailscale IP**: `100.71.184.70`
- **หน้าที่หลัก**: เครื่องใช้งานประจำ (user/client) — เข้าถึง Control UI, Telegram, และสั่งงานผ่าน Sunday
