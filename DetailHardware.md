# 🖥️ ฮาร์ดแวร์และสถาปัตยกรรมระบบ (Hardware Details)

ระบบประกอบด้วย 3 โหนดหลัก ดังนี้:

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

## 2. Worker Node / AI Inference Engine (Ryzen PC)

- **CPU**: AMD Ryzen 5 5600 (6 Cores, 12 Threads)
- **GPU**: NVIDIA RTX 4060 8GB
- **Motherboard**: MSI A520M-A PRO DDR4 (MS-7C96)
- **RAM**: 32GB DDR4
- **Storage**: 512GB NVMe SSD (HS-SSD-FUTURE Eco)
- **PSU**: 550W
- **OS**: Ubuntu 26.04 LTS (Single OS)
- **Local IP**: `192.168.1.27` (Static)
- **Tailscale IP**: `100.82.51.31`
- **SSH**: `ssh ryzenpc` (ใช้ Key: `teaingtit`, Passwordless sudo)
- **หน้าที่หลัก**: ประมวลผล AI และงานที่ต้องใช้ GPU
- **AI Stack**: NVIDIA Driver 590 / Ollama (models: `~/ai-models`) / Tailscale
- **Wake-on-LAN**: `enp34s0` Magic Packet — ปลุกเครื่องผ่าน Master Node ได้
- **Auto-login**: TTY1 เข้า terminal อัตโนมัติ

## 3. Client Node (ASUS ExpertBook)

- **รุ่น**: ASUS EXPERTBOOK P3605CVA
- **CPU**: 13th Gen Intel(R) Core(TM) i5-13420H (8 Cores, 12 Threads)
- **RAM**: 16GB (Samsung, Bus 5600)
- **Storage**: 1TB NVMe SSD (SAMSUNG MZVMA1T0HCLD-00BTW)
- **GPU**: Intel UHD Graphics (2GB VRAM)
- **OS**: Windows
- **Tailscale IP**: `100.71.184.70`
